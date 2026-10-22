// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package steps

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"
	"sync"
)

const (
	completedStatus = "COMPLETED"
	destroyedStatus = "DESTROYED"
	failedStatus    = "FAILED"
	pendingStatus   = "PENDING"
)

// Step represents a single recorded execution step and its state.
type Step struct {
	Name   string `json:"name"`
	Status string `json:"status"`
	Error  string `json:"error"`
}

// String creates a string representation of the step.
func (s Step) String() string {
	if s.Error == "" {
		return fmt.Sprintf("%s %s", s.Name, s.Status)
	}
	return fmt.Sprintf("%s %s error:%s", s.Name, s.Status, s.Error)
}

// StepManager defines the interface for tracking and executing workflow steps.
type StepManager interface {
	RunStep(step string, f func() error) error
	RunDestroyStep(step string, f func() error) error
	IsStepComplete(name string) bool
	IsStepDestroyed(name string) bool
	StepExists(name string) bool
	CompleteStep(name string) error
	FailStep(name string, err string) error
	ResetStep(name string) error
	DestroyStep(name string) error
	GetStepError(name string) string
	ListSteps() []string
	SaveSteps() error
}

// Steps implements a thread-safe StepManager backed by a local JSON file.
type Steps struct {
	File  string          `json:"file"`
	Steps map[string]Step `json:"steps"`
	mu    sync.RWMutex    `json:"-"`
}

// DeleteStepsFile deletes the whole steps file.
func DeleteStepsFile(file string) error {
	_, err := os.Stat(file)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	if !os.IsNotExist(err) {
		return os.Remove(file)
	}
	return nil
}

// LoadSteps loads a previous execution steps from the given file.
func LoadSteps(file string) (*Steps, error) {
	s := &Steps{
		File:  file,
		Steps: make(map[string]Step),
	}
	_, err := os.Stat(file)
	if err != nil && !os.IsNotExist(err) {
		return nil, err
	}
	if os.IsNotExist(err) {
		fmt.Printf("# creating new steps file '%s'.\n", file)
		return s, nil
	}

	f, err := os.ReadFile(file)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(f, s)
	if err != nil {
		return nil, err
	}
	if s.Steps == nil {
		s.Steps = make(map[string]Step)
	}
	return s, nil
}

func (s *Steps) saveStepsLocked() error {
	f, err := json.MarshalIndent(s, "", "    ")
	if err != nil {
		return err
	}
	return os.WriteFile(s.File, f, 0644)
}

// SaveSteps saves the current execution state of the steps to disk.
func (s *Steps) SaveSteps() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.saveStepsLocked()
}

// CompleteStep marks a given step as completed and saves to disk.
func (s *Steps) CompleteStep(name string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.Steps[name] = Step{
		Name:   name,
		Status: completedStatus,
	}
	if err := s.saveStepsLocked(); err != nil {
		return err
	}
	fmt.Printf("# completing step '%s' execution\n", name)
	return nil
}

// IsStepComplete checks if the given step is completed.
func (s *Steps) IsStepComplete(name string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()

	v, ok := s.Steps[name]
	return ok && v.Status == completedStatus
}

// StepExists checks if the given step exists.
func (s *Steps) StepExists(name string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()

	_, ok := s.Steps[name]
	return ok
}

// FailStep marks a given step as failed and saves the error message.
func (s *Steps) FailStep(name string, err string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.Steps[name] = Step{
		Name:   name,
		Status: failedStatus,
		Error:  err,
	}
	return s.saveStepsLocked()
}

func isNested(name string) bool {
	return strings.Contains(name, ".")
}

func parent(name string) string {
	return strings.Split(name, ".")[0]
}

func (s *Steps) resetStepLocked(name string) error {
	s.Steps[name] = Step{
		Name:   name,
		Status: pendingStatus,
	}
	if err := s.saveStepsLocked(); err != nil {
		return err
	}
	fmt.Printf("# resetting step '%s' execution\n", name)
	if isNested(name) {
		return s.resetStepLocked(parent(name))
	}
	return nil
}

// ResetStep resets the execution status of a given step and its parent.
func (s *Steps) ResetStep(name string) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.resetStepLocked(name)
}

// GetStepError gets the error message saved in a step.
func (s *Steps) GetStepError(name string) string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	if v, ok := s.Steps[name]; ok {
		return v.Error
	}
	return ""
}

// ListSteps lists the executed steps.
func (s *Steps) ListSteps() []string {
	s.mu.RLock()
	defer s.mu.RUnlock()

	l := make([]string, 0, len(s.Steps))
	for _, v := range s.Steps {
		l = append(l, v.String())
	}
	sort.Strings(l)
	return l
}

// RunStep executes a step and marks it as completed or failed.
// Completed steps are not executed again.
func (s *Steps) RunStep(step string, f func() error) error {
	if s.IsStepComplete(step) {
		fmt.Printf("# skipping step '%s' execution\n", step)
		return nil
	}
	fmt.Printf("# starting step '%s' execution\n", step)
	err := f()
	if err != nil {
		if failErr := s.FailStep(step, err.Error()); failErr != nil {
			return fmt.Errorf("error on FailStep %v, original error %w", failErr, err)
		}
		return err
	}
	return s.CompleteStep(step)
}

// IsStepDestroyed checks if the step was destroyed.
func (s *Steps) IsStepDestroyed(name string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()

	v, ok := s.Steps[name]
	return ok && v.Status == destroyedStatus
}

// DestroyStep destroys the given step.
func (s *Steps) DestroyStep(name string) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.Steps[name] = Step{
		Name:   name,
		Status: destroyedStatus,
	}
	if err := s.saveStepsLocked(); err != nil {
		return err
	}
	fmt.Printf("# destroying step '%s'\n", name)
	return nil
}

// RunDestroyStep destroys a step and marks it as destroyed or failed.
func (s *Steps) RunDestroyStep(step string, f func() error) error {
	if s.IsStepDestroyed(step) || !s.StepExists(step) {
		fmt.Printf("# skipping step '%s' destruction\n", step)
		return nil
	}
	fmt.Printf("# starting step '%s' destruction\n", step)
	err := f()
	if err != nil {
		if failErr := s.FailStep(step, err.Error()); failErr != nil {
			return fmt.Errorf("error on FailStep %v, original error %w", failErr, err)
		}
		return err
	}
	return s.DestroyStep(step)
}

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

package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	gotest "testing"

	"github.com/mitchellh/go-testing-interface"

	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/msg"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/stages"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/steps"
	"github.com/GoogleCloudPlatform/terraform-google-enterprise-application/helpers/eab-deployer/utils"
)

type cfg struct {
	tfvarsFile    string
	stepsFile     string
	resetStep     string
	quiet         bool
	help          bool
	listSteps     bool
	disablePrompt bool
	validate      bool
	destroy       bool
	exampleName   string
}

func parseFlags() cfg {
	var c cfg

	flag.StringVar(&c.tfvarsFile, "tfvars_file", "", "Full path to the Terraform .tfvars `file` with the configuration to be used.")
	flag.StringVar(&c.stepsFile, "steps_file", ".steps.json", "Path to the steps `file` to be used to save progress.")
	flag.StringVar(&c.resetStep, "reset_step", "", "Name of a `step` to be reset. The step will be marked as pending.")
	flag.BoolVar(&c.quiet, "quiet", false, "If true, additional output is suppressed.")
	flag.BoolVar(&c.help, "help", false, "Prints this help text and exits.")
	flag.BoolVar(&c.listSteps, "list_steps", false, "List the existing steps.")
	flag.BoolVar(&c.disablePrompt, "disable_prompt", false, "Disable interactive prompt.")
	flag.BoolVar(&c.validate, "validate", false, "Validate tfvars file inputs.")
	flag.BoolVar(&c.destroy, "destroy", false, "Destroy the deployment.")
	flag.StringVar(&c.exampleName, "example", "default-example", "Name of the example to deploy (e.g., standalone_single_project, default-example).")

	flag.Parse()
	return c
}

func main() {

	cfg := parseFlags()
	if cfg.help {
		fmt.Println("Deploys the Enterprise Application Blueprint Standalone Single Project")
		flag.PrintDefaults()
		return
	}

	// load tfvars
	globalTFVars, err := stages.ReadGlobalTFVars(cfg.tfvarsFile)
	if err != nil {
		fmt.Printf("# Failed to read GlobalTFVars file. Error: %s\n", err.Error())
		os.Exit(1)
	}

	// init infra
	gotest.Init()
	t := &testing.RuntimeT{}
	conf := stages.CommonConf{
		EABPath:       globalTFVars.EABCodePath,
		CheckoutPath:  globalTFVars.CodeCheckoutPath,
		PolicyPath:    filepath.Join(globalTFVars.EABCodePath, "policy-library"),
		DisablePrompt: cfg.disablePrompt,
		Logger:        utils.GetLogger(cfg.quiet),
		ExampleName:   cfg.exampleName,
	}

	// validate inputs
	if cfg.validate {
		stages.ValidateComponents(t)
		stages.ValidateBasicFields(t, globalTFVars)
		stages.ValidatePermissions(t, globalTFVars)
		return
	}

	// init steps
	s, err := steps.LoadSteps(cfg.stepsFile)
	if err != nil {
		fmt.Printf("# Failed to init state manager. Error: %s\n", err.Error())
		os.Exit(2)
	}

	// list steps
	if cfg.listSteps {
		s.ListSteps()
		return
	}

	// reset step
	if cfg.resetStep != "" {
		err = s.ResetStep(cfg.resetStep)
		if err != nil {
			fmt.Printf("# Reset step failed. Error: %s\n", err.Error())
			os.Exit(3)
		}
		return
	}

	// destroy stages
	if cfg.destroy {
		// Note: destroy is only terraform destroy, local directories are not deleted.
		msg.PrintStageMsg("Destroying Single Project Infrastructure")
		err = stages.DestroyInfraStage(t, s, globalTFVars, conf)
		if err != nil {
			fmt.Printf("# Standalone Infrastructure destroy failed. Error: %s\n", err.Error())
			os.Exit(3)
		}

		// clean up the steps file
		err = steps.DeleteStepsFile(cfg.stepsFile)
		if err != nil {
			fmt.Printf("# failed to delete state file %s. Error: %s\n", cfg.stepsFile, err.Error())
			os.Exit(3)
		}
		return
	}

	// deploy stages

	// 1-infra
	msg.PrintStageMsg("Deploying Standalone Single Project Infrastructure")
	err = stages.DeployInfraStage(t, s, globalTFVars, conf)
	if err != nil {
		fmt.Printf("# Standalone Infrastructure deploy failed. Error: %s\n", err.Error())
		os.Exit(3)
	}

	// 2-appsource
	msg.PrintStageMsg("Deploying Application Source Code and Triggering Pipeline")
	err = stages.DeployAppSourceStage(t, s, globalTFVars, conf)
	if err != nil {
		fmt.Printf("# Application source trigger failed. Error: %s\n", err.Error())
		os.Exit(3)
	}

}

// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.Multitenant/licenses/LICENSE-2.0
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

	"github.com/terraform-google-modules/terraform-example-foundation/helpers/foundation-deployer/msg"
	"github.com/terraform-google-modules/terraform-example-foundation/helpers/foundation-deployer/stages"
	"github.com/terraform-google-modules/terraform-example-foundation/helpers/foundation-deployer/steps"
	"github.com/terraform-google-modules/terraform-example-foundation/helpers/foundation-deployer/utils"
)

var (
	validatorApis = []string{
		"securitycenter.googleapis.com",
		"accesscontextmanager.googleapis.com",
	}
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

	flag.Parse()
	return c
}

func main() {

	cfg := parseFlags()
	if cfg.help {
		fmt.Println("Deploys the Enterprise Application Blueprint")
		flag.PrintDefaults()
		return
	}

	// load tfvars
	globalTFVars, err := stages.ReadGlobalTFVars(cfg.tfvarsFile)
	if err != nil {
		fmt.Printf("# Failed to read GlobalTFVars file. Error: %s\n", err.Error())
		os.Exit(1)
	}

	// validate Directories
	err = stages.ValidateDirectories(globalTFVars)
	if err != nil {
		fmt.Printf("# Failed validating directories. Error: %s\n", err.Error())
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
	}

	// validate inputs
	if cfg.validate {
		stages.ValidateBasicFields(t, globalTFVars)
		stages.ValidateDestroyFlags(t, globalTFVars)
		return
	}

	s, err := steps.LoadSteps(cfg.stepsFile)
	if err != nil {
		fmt.Printf("# failed to load state file %s. Error: %s\n", cfg.stepsFile, err.Error())
		os.Exit(2)
	}

	if cfg.listSteps {
		fmt.Println("# Executed steps:")
		e := s.ListSteps()
		if len(e) == 0 {
			fmt.Println("# No steps executed")
			return
		}
		for _, step := range e {
			fmt.Println(step)
		}
		return
	}

	if cfg.resetStep != "" {
		if err := s.ResetStep(cfg.resetStep); err != nil {
			fmt.Printf("# Reset step failed. Error: %s\n", err.Error())
			os.Exit(3)
		}
		return
	}

	// destroy stages
	if cfg.destroy {
		// Note: destroy is only terraform destroy, local directories are not deleted.
		// 5-appinfra
		msg.PrintStageMsg("Destroying 5-appinfra stage")
		err = s.RunDestroyStep("apps/default-example/hello-world", func() error {
			io := stages.GetAppFactoryStepOutputs(t, conf.CheckoutPath)
			return stages.DestroyAppInfraStage(t, s, io, conf)
		})
		if err != nil {
			fmt.Printf("# Example app step destroy failed. Error: %s\n", err.Error())
			os.Exit(3)
		}

		// 4-appfactory
		msg.PrintStageMsg("Destroying 4-appfactory stage")
		err = s.RunDestroyStep("gcp-appfactory", func() error {
			bo := stages.GetBootstrapStepOutputs(t, conf.EABPath)
			return stages.DestroyAppFactoryStage(t, s, bo, conf)
		})
		if err != nil {
			fmt.Printf("# AppFactory step destroy failed. Error: %s\n", err.Error())
			os.Exit(3)
		}

		// 3-fleetscope
		msg.PrintStageMsg("Destroying 3-fleetscope stage")
		err = s.RunDestroyStep("gcp-networks", func() error {
			bo := stages.GetBootstrapStepOutputs(t, conf.EABPath)
			return stages.DestroyFleetscopeStage(t, s, bo, conf)
		})
		if err != nil {
			fmt.Printf("# Fleetscope step destroy failed. Error: %s\n", err.Error())
			os.Exit(3)
		}

		// 3-fleetscope
		msg.PrintStageMsg("Destroying 3-fleetscope stage")
		err = s.RunDestroyStep("gcp-fleetscope", func() error {
			bo := stages.GetBootstrapStepOutputs(t, conf.EABPath)
			return stages.DestroyFleetscopeStage(t, s, bo, conf)
		})
		if err != nil {
			fmt.Printf("# Fleetscope step destroy failed. Error: %s\n", err.Error())
			os.Exit(3)
		}

		// 2-Multitenant
		msg.PrintStageMsg("Destroying 2-Multitenant stage")
		err = s.RunDestroyStep("gcp-Multitenant", func() error {
			bo := stages.GetBootstrapStepOutputs(t, conf.EABPath)
			return stages.DestroyMultitenantStage(t, s, bo, conf)
		})
		if err != nil {
			fmt.Printf("# Multitenant step destroy failed. Error: %s\n", err.Error())
			os.Exit(3)
		}

		// 0-bootstrap
		msg.PrintStageMsg("Destroying 0-bootstrap stage")
		err = s.RunDestroyStep("gcp-bootstrap", func() error {
			return stages.DestroyBootstrapStage(t, s, conf)
		})
		if err != nil {
			fmt.Printf("# Bootstrap step destroy failed. Error: %s\n", err.Error())
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

	// 0-bootstrap
	msg.PrintStageMsg("Deploying 0-bootstrap stage")
	skipInnerBuildMsg := s.IsStepComplete("gcp-bootstrap")
	err = s.RunStep("gcp-bootstrap", func() error {
		return stages.DeployBootstrapStage(t, s, globalTFVars, conf)
	})
	if err != nil {
		fmt.Printf("# Bootstrap step failed. Error: %s\n", err.Error())
		os.Exit(3)
	}

	bo := stages.GetBootstrapStepOutputs(t, conf.EABPath)

	if skipInnerBuildMsg {
		msg.PrintBuildMsg(bo.ProjectID, "us-central1", conf.DisablePrompt)
	}
	msg.PrintQuotaMsg(bo.CBServiceAccountsEmails["appfactory"], conf.DisablePrompt)

	// 2-Multitenant
	msg.PrintStageMsg("Deploying 2-Multitenant stage")
	err = s.RunStep("gcp-Multitenant", func() error {
		return stages.DeployMultitenantStage(t, s, globalTFVars, bo, conf)
	})
	if err != nil {
		fmt.Printf("# Multitenant step failed. Error: %s\n", err.Error())
		os.Exit(3)
	}

	// 3-fleetscope
	msg.PrintStageMsg("Deploying 3-fleetscope stage")
	err = s.RunStep("gcp-environments", func() error {
		return stages.DeployFleetscopeStage(t, s, globalTFVars, bo, conf)
	})
	if err != nil {
		fmt.Printf("# Fleetscope step failed. Error: %s\n", err.Error())
		os.Exit(3)
	}

	// 4-appfactory
	msg.PrintStageMsg("Deploying 4-appfactory stage")
	msg.ConfirmQuota(bo.CBServiceAccountsEmails["appfactory"], conf.DisablePrompt)

	err = s.RunStep("gcp-projects", func() error {
		return stages.DeployAppFactoryStage(t, s, globalTFVars, bo, conf)
	})
	if err != nil {
		fmt.Printf("# Projects step failed. Error: %s\n", err.Error())
		os.Exit(3)
	}

	// 5-appinfra
	msg.PrintStageMsg("Deploying 5-appinfra stage")
	io := stages.GetAppFactoryStepOutputs(t, conf.CheckoutPath)

	err = s.RunStep("hello-world", func() error {
		return stages.DeployAppInfraStage(t, s, globalTFVars, io, conf)
	})
	if err != nil {
		fmt.Printf("# Example app step failed. Error: %s\n", err.Error())
		os.Exit(3)
	}

	// // 6-appsource
	// msg.PrintStageMsg("Deploying 6-appsource stage")
	// err = s.RunStep("gcp-networks", func() error {
	// 	return stages.DeployFleetscopeStage(t, s, globalTFVars, bo, conf)
	// })
	// if err != nil {
	// 	fmt.Printf("# Networks step failed. Error: %s\n", err.Error())
	// 	os.Exit(3)
	// }

}

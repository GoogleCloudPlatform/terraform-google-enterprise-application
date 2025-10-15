// Copyright 2024 Google LLC
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

package cymbalbank_e2e

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
	"github.com/gruntwork-io/terratest/modules/retry"
)

const (
	sleepBetweenRetries time.Duration = time.Duration(60) * time.Second
	maxRetries          int           = 40
)

func TestCymbalBankE2E(t *testing.T) {
	multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/development"))
	t.Run("End to end tests Cymbal Bank Multitenant", func(t *testing.T) {
		jar, err := cookiejar.New(nil)
		if err != nil {
			t.Fatal(err)
		}
		client := &http.Client{
			Jar: jar,
		}
		ctx := context.Background()
		ipAddress := multitenant.GetJsonOutput("app_ip_addresses").Get("cymbal-bank.cb-frontend-ip").String()

		// Test webserver is avaliable
		heartbeat := func() (string, error) {
			req, err := http.NewRequestWithContext(ctx, "GET", fmt.Sprintf("http://%s", ipAddress), nil)
			if err != nil {
				return "", err
			}
			resp, err := client.Do(req)
			if err != nil {
				return "", err
			}
			if resp.StatusCode != 200 {
				fmt.Println(resp)
				return "", err
			}
			return fmt.Sprint(resp.StatusCode), err
		}
		statusCode, _ := retry.DoWithRetryE(
			t,
			fmt.Sprintf("Checking: %s", ipAddress),
			maxRetries,
			sleepBetweenRetries,
			heartbeat,
		)
		if err != nil {
			t.Fatalf("Error: webserver (%s) not ready after %d attemps, status code: %q",
				ipAddress,
				maxRetries,
				statusCode,
			)
		}

		resp, err := login(ctx, client, ipAddress)

		// check if the server replied with authentication cookie
		gotToken := false
		for _, cookie := range resp.Request.Cookies() {
			if cookie.Name == "token" {
				gotToken = true
			}
		}

		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}

		if !gotToken {
			fmt.Println("Failed Authentication.")
			fmt.Println(resp.Request)
			t.Fatal(err)
		}

		fmt.Printf("Login resp: %v \n", resp)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}

		resp, err = home(ctx, client, ipAddress)
		fmt.Printf("Home resp: %v \n", resp)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}

		resp, err = deposit(ctx, client, ipAddress)
		fmt.Printf("Deposit resp: %v \n", resp)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}

		_, err = checkTransaction(ctx, client, ipAddress, "5,230.00", "DEPOSIT")
		if err != nil {
			t.Fatal(err)
		}
		resp, err = transfer(ctx, client, ipAddress)
		fmt.Printf("Transfer resp: %v \n", resp)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}
		_, err = checkTransaction(ctx, client, ipAddress, "320.98", "PAYMENT")
		if err != nil {
			t.Fatal(err)
		}
	})
}

func login(ctx context.Context, c *http.Client, ipAddress string) (*http.Response, error) {
	fmt.Println("APP Login.")
	loginUrl := fmt.Sprintf("http://%s/login", ipAddress)
	form := make(url.Values)
	form.Add("username", "testuser")
	form.Add("password", "bankofanthos")
	b := strings.NewReader(form.Encode())
	req, err := http.NewRequestWithContext(ctx, "POST", loginUrl, b)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	return c.Do(req)
}

func home(ctx context.Context, c *http.Client, ipAddress string) (*http.Response, error) {

	homeUrl := fmt.Sprintf("http://%s/home", ipAddress)
	req, err := http.NewRequestWithContext(ctx, "GET", homeUrl, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	return c.Do(req)
}

func deposit(ctx context.Context, c *http.Client, ipAddress string) (*http.Response, error) {
	fmt.Println("APP Deposit.")
	depositUrl := fmt.Sprintf("http://%s/deposit", ipAddress)
	form := make(url.Values)
	form.Add("account", "{\"account_num\": \"9099791699\", \"routing_num\": \"808889588\"}")
	form.Add("external_account_num", "")
	form.Add("external_routing_num", "")
	form.Add("external_label", "")
	form.Add("amount", "5230.00")
	form.Add("uuid", uuid.NewString())
	req, err := http.NewRequestWithContext(ctx, "POST", depositUrl, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	fmt.Printf("Deposit value: %s \n", form.Get("amount"))
	return c.Do(req)
}

func checkTransaction(ctx context.Context, c *http.Client, ipAddress string, amount string, typeTransaction string) (*http.Response, error) {
	resp, err := home(ctx, c, ipAddress)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != 200 {
		fmt.Println(resp)
		return nil, err
	}
	defer func() {
		if err := resp.Body.Close(); err != nil {
			// Consider passing *testing.T to this function to use t.Errorf() for logging.
			fmt.Printf("Error closing response body: %v\n", err)
		}
	}()
	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	bodyString := string(bodyBytes)
	switch typeTransaction {
	case "DEPOSIT":
		amount = fmt.Sprintf("+$%s", amount)
	case "PAYMENT":
		amount = fmt.Sprintf("-$%s", amount)
	}
	if !strings.Contains(bodyString, amount) {
		fmt.Printf("Error on %s!\n", typeTransaction)
		return nil, fmt.Errorf("Error on %s!\n", typeTransaction)
	}
	return resp, nil
}

func transfer(ctx context.Context, c *http.Client, ipAddress string) (*http.Response, error) {
	fmt.Println("APP Transfer.")
	transferUrl := fmt.Sprintf("http://%s/payment", ipAddress)
	form := make(url.Values)
	form.Add("account_num", "1077441377")
	form.Add("contact_account_num", "")
	form.Add("contact_label", "")
	form.Add("amount", "320.98")
	form.Add("uuid", uuid.NewString())
	req, err := http.NewRequestWithContext(ctx, "POST", transferUrl, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	fmt.Printf("Transfer value: %s \n", form.Get("amount"))
	return c.Do(req)
}

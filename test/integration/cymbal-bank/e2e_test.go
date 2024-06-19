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
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"strings"
	"testing"

	"github.com/google/uuid"

	"github.com/GoogleCloudPlatform/cloud-foundation-toolkit/infra/blueprint-test/pkg/tft"
)

func TestAppE2E(t *testing.T) {
	multitenant := tft.NewTFBlueprintTest(t, tft.WithTFDir("../../../2-multitenant/envs/development"))
	t.Run("End to end tests", func(t *testing.T) {
		jar, err := cookiejar.New(nil)
		if err != nil {
			t.Fatal(err)
		}
		client := &http.Client{
			Jar: jar,
		}
		ctx := context.Background()
		ipAddress := multitenant.GetJsonOutput("app_ip_addresses").Get("cymbal-bank.frontend-ip").String()
		fmt.Println("APP Login.")
		resp, err := login(ctx, client, ipAddress)
		fmt.Println(resp)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}

		fmt.Println("APP Home.")
		resp, err = home(ctx, client, ipAddress)
		fmt.Println(resp)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}
		fmt.Println(resp)

		fmt.Println("APP Deposit.")
		resp, err = deposit(ctx, client, ipAddress)
		fmt.Println(resp)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}

		fmt.Println("APP Transfer.")
		resp, err = transfer(ctx, client, ipAddress)
		fmt.Println(resp)
		if err != nil {
			t.Fatal(err)
		}
		if resp.StatusCode != 200 {
			fmt.Println(resp)
			t.Fatal(err)
		}

	})
}

func login(ctx context.Context, c *http.Client, ipAddress string) (*http.Response, error) {
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
	depositUrl := fmt.Sprintf("http://%s/deposit", ipAddress)
	form := make(url.Values)
	form.Add("account", "{\"account_num\": \"9099791699\", \"routing_num\": \"808889588\"}")
	form.Add("external_account_num", "")
	form.Add("external_routing_num", "")
	form.Add("external_label", "")
	form.Add("amount", "100.00")
	form.Add("uuid", uuid.NewString())
	req, err := http.NewRequestWithContext(ctx, "POST", depositUrl, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	return c.Do(req)
}

func transfer(ctx context.Context, c *http.Client, ipAddress string) (*http.Response, error) {
	transferUrl := fmt.Sprintf("http://%s/payment", ipAddress)
	form := make(url.Values)
	form.Add("account_num", "1033623433")
	form.Add("contact_account_num", "")
	form.Add("contact_label", "")
	form.Add("amount", "113.00")
	form.Add("uuid", uuid.NewString())
	req, err := http.NewRequestWithContext(ctx, "POST", transferUrl, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	return c.Do(req)
}

package pwdtest

import (
	"os"
	"testing"
)

func TestPwd(t *testing.T) {
	pwd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
		return
	}

	t.Log("current wd:")
	t.Log(pwd)
}

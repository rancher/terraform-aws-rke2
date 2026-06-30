package test

import (
	"fmt"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/ec2/types"
)

func TestFilter(_ *testing.T) {
	f := types.Filter{}
	fmt.Printf("%T\n", f.Values)
}

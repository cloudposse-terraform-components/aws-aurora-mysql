package test

import (
	"strings"
	"testing"

	"github.com/cloudposse/test-helpers/pkg/atmos"
	helper "github.com/cloudposse/test-helpers/pkg/atmos/component-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/stretchr/testify/assert"
)

type ComponentSuite struct {
	helper.TestSuite
}

func (s *ComponentSuite) TestBasic() {
	const component = "aurora-mysql/basic"
	const stack = "default-test"

	clusterName := strings.ToLower(random.UniqueId())

	defer s.DestroyAtmosComponent(s.T(), component, stack, nil)
	inputs := map[string]interface{}{
		"mysql_name":             clusterName,
		"mysql_db_name":          "mydb",
		"mysql_admin_user":       "admin",
		"mysql_db_port":          3306,
		"publicly_accessible":    true,
		"allowed_cidr_blocks":    []string{"0.0.0.0/0"},
		"mysql_deletion_protection": false,
		"mysql_skip_final_snapshot": true,
	}
	componentInstance, _ := s.DeployAtmosComponent(s.T(), component, stack, &inputs)
	assert.NotNil(s.T(), componentInstance)

	clusterName_ := atmos.Output(s.T(), componentInstance, "aurora_mysql_cluster_name")
	assert.NotEmpty(s.T(), clusterName_)

	masterHostname := atmos.Output(s.T(), componentInstance, "aurora_mysql_master_hostname")
	assert.NotEmpty(s.T(), masterHostname)

	replicasHostname := atmos.Output(s.T(), componentInstance, "aurora_mysql_replicas_hostname")
	assert.NotEmpty(s.T(), replicasHostname)

	endpoint := atmos.Output(s.T(), componentInstance, "aurora_mysql_endpoint")
	assert.NotEmpty(s.T(), endpoint)

	readerEndpoint := atmos.Output(s.T(), componentInstance, "aurora_mysql_reader_endpoint")
	assert.NotEmpty(s.T(), readerEndpoint)

	kmsKeyArn := atmos.Output(s.T(), componentInstance, "kms_key_arn")
	assert.NotEmpty(s.T(), kmsKeyArn)

	// Verify proxy outputs are nil/empty when proxy is not enabled
	proxyEndpoint := atmos.Output(s.T(), componentInstance, "proxy_endpoint")
	assert.Empty(s.T(), proxyEndpoint)

	proxySecurityGroupId := atmos.Output(s.T(), componentInstance, "proxy_security_group_id")
	assert.Empty(s.T(), proxySecurityGroupId)

	s.DriftTest(component, stack, &inputs)
}

func (s *ComponentSuite) TestDisabled() {
	const component = "aurora-mysql/disabled"
	const stack = "default-test"

	s.VerifyEnabledFlag(component, stack, nil)
}

func TestRunSuite(t *testing.T) {
	suite := new(ComponentSuite)

	suite.AddDependency(t, "vpc", "default-test", nil)

	subdomain := strings.ToLower(random.UniqueId())
	inputs := map[string]interface{}{
		"zone_config": []map[string]interface{}{
			{
				"subdomain": subdomain,
				"zone_name": "components.cptest.test-automation.app",
			},
		},
	}
	suite.AddDependency(t, "dns-delegated", "default-test", &inputs)
	helper.Run(t, suite)
}

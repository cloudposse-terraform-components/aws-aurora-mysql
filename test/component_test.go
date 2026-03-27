package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/cloudposse/test-helpers/pkg/atmos"
	helper "github.com/cloudposse/test-helpers/pkg/atmos/component-helper"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/stretchr/testify/assert"
)

type ComponentSuite struct {
	helper.TestSuite
}

func (s *ComponentSuite) TestBasic() {
	const component = "aurora-mysql/basic"
	const stack = "default-test"
	const awsRegion = "us-east-2"

	mysqlName := strings.ToLower(random.UniqueId())

	defer s.DestroyAtmosComponent(s.T(), component, stack, nil)
	inputs := map[string]interface{}{
		"mysql_name":                mysqlName,
		"mysql_db_name":             "mydb",
		"mysql_admin_user":          "admin",
		"mysql_db_port":             3306,
		"publicly_accessible":       true,
		"allowed_cidr_blocks":       []string{"0.0.0.0/0"},
		"mysql_deletion_protection": false,
		"mysql_skip_final_snapshot": true,
	}
	componentInstance, _ := s.DeployAtmosComponent(s.T(), component, stack, &inputs)
	assert.NotNil(s.T(), componentInstance)

	clusterName := atmos.Output(s.T(), componentInstance, "aurora_mysql_cluster_name")
	assert.NotEmpty(s.T(), clusterName)

	delegatedDnsOptions := s.GetAtmosOptions("dns-delegated", stack, nil)
	delegatedDomainName := atmos.Output(s.T(), delegatedDnsOptions, "default_domain_name")
	delegatedDomainZoneId := atmos.Output(s.T(), delegatedDnsOptions, "default_dns_zone_id")

	// cluster_subdomain = mysql_name + "." + name (when mysql_name != "")
	// cluster_dns_name  = "master." + cluster_subdomain
	componentName := fmt.Sprintf("%v", componentInstance.Vars["name"])
	masterHostname := atmos.Output(s.T(), componentInstance, "aurora_mysql_master_hostname")
	expectedMasterHostname := fmt.Sprintf("master.%s.%s.%s", mysqlName, componentName, delegatedDomainName)
	assert.Equal(s.T(), expectedMasterHostname, masterHostname)

	replicasHostname := atmos.Output(s.T(), componentInstance, "aurora_mysql_replicas_hostname")
	expectedReplicasHostname := fmt.Sprintf("readers.%s.%s.%s", mysqlName, componentName, delegatedDomainName)
	assert.Equal(s.T(), expectedReplicasHostname, replicasHostname)

	endpoint := atmos.Output(s.T(), componentInstance, "aurora_mysql_endpoint")
	assert.NotEmpty(s.T(), endpoint)

	readerEndpoint := atmos.Output(s.T(), componentInstance, "aurora_mysql_reader_endpoint")
	assert.NotEmpty(s.T(), readerEndpoint)

	kmsKeyArn := atmos.Output(s.T(), componentInstance, "kms_key_arn")
	assert.NotEmpty(s.T(), kmsKeyArn)

	// Verify Route53 DNS record for master hostname points at the cluster endpoint
	masterHostnameDNSRecord := aws.GetRoute53Record(s.T(), delegatedDomainZoneId, masterHostname, "CNAME", awsRegion)
	assert.Equal(s.T(), endpoint, *masterHostnameDNSRecord.ResourceRecords[0].Value)

	// Verify the expected number of SSM parameters were written:
	// 4 default + 1 replicas (cluster_size > 0) + 2 admin = 7
	ssmKeyPaths := atmos.OutputList(s.T(), componentInstance, "ssm_key_paths")
	assert.Equal(s.T(), 7, len(ssmKeyPaths))

	adminUsername := atmos.Output(s.T(), componentInstance, "aurora_mysql_master_username")
	assert.Equal(s.T(), inputs["mysql_admin_user"], adminUsername)

	// Verify config_map has the expected connection details
	configMap := map[string]interface{}{}
	atmos.OutputStruct(s.T(), componentInstance, "config_map", &configMap)
	assert.Equal(s.T(), clusterName, configMap["cluster"])
	assert.Equal(s.T(), inputs["mysql_db_name"], configMap["database"])
	assert.Equal(s.T(), masterHostname, configMap["hostname"])
	assert.EqualValues(s.T(), inputs["mysql_db_port"], configMap["port"])
	assert.Equal(s.T(), adminUsername, configMap["username"])
	assert.Equal(s.T(), endpoint, configMap["endpoint"])

	passwordSSMKey, ok := configMap["password_ssm_key"].(string)
	assert.True(s.T(), ok, "password_ssm_key should be a string")

	adminUserPassword := aws.GetParameter(s.T(), awsRegion, passwordSSMKey)
	dbPort := int32(inputs["mysql_db_port"].(int))
	dbName := inputs["mysql_db_name"].(string)

	// Verify DB connectivity through the cluster endpoint, master hostname, and replicas hostname
	schemaExists := aws.GetWhetherSchemaExistsInRdsMySqlInstance(s.T(), endpoint, dbPort, adminUsername, adminUserPassword, dbName)
	assert.True(s.T(), schemaExists)

	schemaExists = aws.GetWhetherSchemaExistsInRdsMySqlInstance(s.T(), masterHostname, dbPort, adminUsername, adminUserPassword, dbName)
	assert.True(s.T(), schemaExists)

	schemaExists = aws.GetWhetherSchemaExistsInRdsMySqlInstance(s.T(), replicasHostname, dbPort, adminUsername, adminUserPassword, dbName)
	assert.True(s.T(), schemaExists)

	// Verify proxy outputs are empty/nil when proxy is not enabled
	proxyEndpoint := atmos.Output(s.T(), componentInstance, "proxy_endpoint")
	assert.Empty(s.T(), proxyEndpoint)

	proxySecurityGroupId := atmos.Output(s.T(), componentInstance, "proxy_security_group_id")
	assert.Empty(s.T(), proxySecurityGroupId)

	// Verify cluster security group ID is populated
	clusterSecurityGroupId := atmos.Output(s.T(), componentInstance, "security_group_id")
	assert.NotEmpty(s.T(), clusterSecurityGroupId)

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

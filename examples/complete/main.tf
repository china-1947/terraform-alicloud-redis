variable "region" {
  default = "cn-beijing"
}
provider "alicloud" {
  region = var.region
}
locals {
  engine         = "Redis"
  engine_version = "4.0"
  edition_type   = "Community"
  architecture   = "cluster"
}
data "alicloud_vpcs" "default" {
  is_default = true
}

data "alicloud_vswitches" "default" {
  zone_id = data.alicloud_zones.default.zones.0.multi_zone_ids.0
  vpc_id =  length(data.alicloud_vpcs.default.ids) > 0 ? "${data.alicloud_vpcs.default.ids.0}" : alicloud_vpc.default.0.id
}

resource "alicloud_vpc" "default" {
  count = length(data.alicloud_vpcs.default.ids) > 0 ? 0 : 1
  cidr_block = "172.16.0.0/12"
  vpc_name = "test_vpc_007"
}

data "alicloud_zones" "default" {
  available_resource_creation = "KVStore"
  multi                       = true
  enable_details              = true
}

data "alicloud_kvstore_instance_classes" "default" {
  zone_id        = data.alicloud_zones.default.zones.0.multi_zone_ids.0
  engine         = local.engine
  engine_version = local.engine_version
  architecture   = local.architecture
}

resource "alicloud_vswitch" "this" {
  count = length(data.alicloud_vswitches.default.ids) > 0 ? 0 : 1
  vswitch_name              = "redis_vpc_007"
  zone_id                   = data.alicloud_zones.default.zones.0.multi_zone_ids.0
  vpc_id                    = length(data.alicloud_vpcs.default.ids) > 0 ?  data.alicloud_vpcs.default.vpcs.0.id : alicloud_vpc.default.0.id
  cidr_block                = "172.16.0.0/24"
}

module "redis_example" {
  source = "../../"
  region = var.region

  #################
  # Redis Instance
  #################

  engine_version    = local.engine_version
  instance_name     = "myInstance"
  instance_class    = "redis.logic.sharding.2g.8db.0rodb.8proxy.default"
  password          = "Yourpwd123456"
  period            = 1
  availability_zone = data.alicloud_zones.default.zones.0.multi_zone_ids.0
  vswitch_id        = length(data.alicloud_vswitches.default.ids) > 0 ? data.alicloud_vswitches.default.ids.0 : alicloud_vswitch.this.0.id
  security_ips      = ["1.1.1.1", "2.2.2.2", "3.3.3.3"]
  tags = {
    Env      = "Private"
    Location = "Secret"
  }

  #################
  # Redis backup_policy
  #################

  backup_policy_backup_time   = "02:00Z-03:00Z"
  backup_policy_backup_period = ["Monday", "Wednesday", "Friday"]

  #################
  # Redis account
  #################

  accounts = [
    {
      account_name      = "user1"
      account_password  = "plan111111"
      account_privilege = "RoleReadOnly"
      account_type      = "Normal"
    },
    {
      account_name     = "user2"
      account_password = "plan222222"
    },
  ]

  #############
  # cms_alarm
  #############
  alarm_rule_name            = "CmsAlarmForRedis"
  alarm_rule_statistics      = "Average"
  alarm_rule_period          = 300
  alarm_rule_operator        = "<="
  alarm_rule_threshold       = 35
  alarm_rule_triggered_count = 2
  alarm_rule_contact_groups  = ["AccCms"]
}
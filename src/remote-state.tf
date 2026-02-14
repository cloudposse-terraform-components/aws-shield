module "account_map" {
  source  = "cloudposse/stack-config/yaml//modules/remote-state"
  version = "1.8.0"

  component   = var.account_map_component_name
  tenant      = var.account_map_enabled ? coalesce(var.account_map_tenant, module.this.tenant) : null
  stage       = var.account_map_enabled ? var.root_account_stage : null
  environment = var.account_map_enabled ? var.global_environment : null
  privileged  = var.privileged

  context = module.this.context

  bypass   = !var.account_map_enabled
  defaults = var.account_map
}

module "alb" {
  count   = local.alb_protection_enabled == false ? 0 : length(var.alb_names) > 0 ? 0 : 1
  source  = "cloudposse/stack-config/yaml//modules/remote-state"
  version = "1.8.0"

  component = "eks/alb-controller-ingress-group"

  context = module.this.context
}

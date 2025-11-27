---
tags:
  - component/aws-shield
  - layer/security-and-compliance
  - provider/aws
---

# Component: `shield`

This component is responsible for enabling AWS Shield Advanced Protection for the following resources:

- Application Load Balancers (ALBs)
- CloudFront Distributions
- Elastic IPs (NAT Gateways, EC2 instances)
- Route53 Hosted Zones

## About AWS Shield

AWS Shield is a managed DDoS (Distributed Denial of Service) protection service that safeguards applications running on AWS.

**AWS Shield has two tiers:**

| Feature | Shield Standard | Shield Advanced |
|---------|-----------------|-----------------|
| **Cost** | Free (included with AWS) | $3,000/month per organization |
| **Protection** | Layer 3/4 (network/transport) | Layer 3/4/7 (includes application layer) |
| **Resources** | All AWS resources | Specific protected resources |
| **DRT Access** | No | Yes (24/7 DDoS Response Team) |
| **Cost Protection** | No | Yes (credits for DDoS-related scaling) |
| **Advanced Metrics** | No | Yes (CloudWatch metrics) |
| **WAF Integration** | Basic | Advanced (custom rules during attacks) |

This component configures **AWS Shield Advanced** protection for specific resources.

## Prerequisites

This component requires that the account where it is being provisioned has been
[subscribed to AWS Shield Advanced](https://docs.aws.amazon.com/waf/latest/developerguide/enable-ddos-prem.html).

**Important:** The Shield Advanced subscription is a **manual step** that must be completed before deploying this component:

```shell
# Subscribe via AWS CLI
aws shield create-subscription

# Or subscribe via AWS Console:
# AWS Shield → Getting started → Subscribe to Shield Advanced
```

This component assumes that resources it is configured to protect are not already protected by other components that
have their `xxx_aws_shield_protection_enabled` variable set to `true`.
## Usage

**Stack Level**: Global or Regional

AWS Shield Advanced protects both global and regional resources. Deploy this component to the appropriate stack level
based on the resources you want to protect:

| Resource Type | Stack Level | Example Stack |
|---------------|-------------|---------------|
| Route53 Hosted Zones | Global | `plat-gbl-prod-shield` |
| CloudFront Distributions | Global | `plat-gbl-prod-shield` |
| Application Load Balancers | Regional | `plat-use1-prod-shield` |
| Elastic IPs | Regional | `plat-use1-prod-shield` |

### Complete Example (All Resources)

The following snippet shows how to use all of this component's features in a stack configuration:

```yaml
components:
  terraform:
    aws-shield:
      metadata:
        component: aws-shield
      settings:
        spacelift:
          workspace_enabled: true
      vars:
        enabled: true
        # Global resources
        route53_zone_names:
          - example.com
          - api.example.com
        cloudfront_distribution_ids:
          - E1ABCDEFG12345
          - E2BCDEFGH23456
        # Regional resources
        alb_protection_enabled: true
        alb_names:
          - k8s-common-2c5f23ff99
          - api-gateway-alb
        eips:
          - 3.214.128.240    # NAT Gateway AZ-a
          - 35.172.208.150   # NAT Gateway AZ-b
          - 35.171.70.50     # Bastion host
```

### Global Stack Configuration

A typical global configuration includes Route53 hosted zones and CloudFront distributions.
Global stacks typically don't have a VPC, so `alb_names` and `eips` should not be defined:

```yaml
# stacks/catalog/aws-shield/global.yaml
components:
  terraform:
    aws-shield:
      metadata:
        component: aws-shield
      settings:
        spacelift:
          workspace_enabled: true
      vars:
        enabled: true
        route53_zone_names:
          - example.com
          - internal.example.com
        cloudfront_distribution_ids:
          - E1ABCDEFG12345
```

### Regional Stack Configuration

Regional configurations protect ALBs and Elastic IPs. CloudFront distributions should not be defined
in regional stacks (they are global resources):

```yaml
# stacks/catalog/aws-shield/regional.yaml
components:
  terraform:
    aws-shield:
      metadata:
        component: aws-shield
      settings:
        spacelift:
          workspace_enabled: true
      vars:
        enabled: true
        # Protect ALBs by name
        alb_protection_enabled: true
        alb_names:
          - k8s-common-2c5f23ff99
        # Protect Elastic IPs (NAT Gateways, EC2 instances)
        eips:
          - 3.214.128.240
          - 35.172.208.150
        # Regional Route53 zones (if any)
        route53_zone_names:
          - us-east-1.example.com
```

### Auto-Discovery from EKS ALB Controller

When `alb_protection_enabled` is `true` and `alb_names` is empty, the component automatically discovers
ALB names from the `eks/alb-controller-ingress-group` component via remote state:

```yaml
components:
  terraform:
    aws-shield:
      vars:
        enabled: true
        # Enable ALB protection with auto-discovery
        alb_protection_enabled: true
        # alb_names is intentionally empty - will be discovered from EKS ALB controller
```

### Catalog Defaults Pattern

Create a catalog defaults file that can be imported and customized per environment:

```yaml
# stacks/catalog/aws-shield/defaults.yaml
components:
  terraform:
    aws-shield:
      metadata:
        component: aws-shield
      vars:
        enabled: true
        alb_protection_enabled: false
        alb_names: []
        eips: []
        route53_zone_names: []
        cloudfront_distribution_ids: []
```

Then import and override in your stack:

```yaml
# stacks/orgs/acme/platform/prod/us-east-1/shield.yaml
import:
  - catalog/aws-shield/defaults

components:
  terraform:
    aws-shield:
      vars:
        alb_protection_enabled: true
        alb_names:
          - prod-api-alb
        eips:
          - 52.1.2.3
```

### Integration with Other Components

Stack configurations that rely on components with a `xxx_aws_shield_protection_enabled` variable should set that
variable to `true` and leave the corresponding variable for this component empty, relying on that component's AWS
Shield Advanced functionality instead. This simplifies inter-component dependencies and minimizes the need
for maintaining the provisioning order during a cold-start.

### Finding Resource Identifiers

Use the following AWS CLI commands to find resource identifiers:

```shell
# List ALB names
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerName' --output table

# List Elastic IPs
aws ec2 describe-addresses --query 'Addresses[*].[PublicIp,AllocationId,Tags[?Key==`Name`].Value|[0]]' --output table

# List Route53 hosted zones
aws route53 list-hosted-zones --query 'HostedZones[*].[Name,Id]' --output table

# List CloudFront distributions
aws cloudfront list-distributions --query 'DistributionList.Items[*].[Id,DomainName,Origins.Items[0].DomainName]' --output table
```

### Verifying Protection Status

After deployment, verify resources are protected:

```shell
# List all protected resources
aws shield list-protections --query 'Protections[*].[Name,ResourceArn]' --output table

# Describe a specific protection
aws shield describe-protection --resource-arn <resource-arn>

# Check subscription status
aws shield describe-subscription
```

<!-- prettier-ignore-start -->
<!-- prettier-ignore-end -->


<!-- markdownlint-disable -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alb"></a> [alb](#module\_alb) | cloudposse/stack-config/yaml//modules/remote-state | 1.8.0 |
| <a name="module_iam_roles"></a> [iam\_roles](#module\_iam\_roles) | ../account-map/modules/iam-roles | n/a |
| <a name="module_this"></a> [this](#module\_this) | cloudposse/label/null | 0.25.0 |

## Resources

| Name | Type |
|------|------|
| [aws_shield_protection.alb_shield_protection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/shield_protection) | resource |
| [aws_shield_protection.cloudfront_shield_protection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/shield_protection) | resource |
| [aws_shield_protection.eip_shield_protection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/shield_protection) | resource |
| [aws_shield_protection.route53_zone_protection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/shield_protection) | resource |
| [aws_alb.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/alb) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_cloudfront_distribution.cloudfront_distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/cloudfront_distribution) | data source |
| [aws_eip.eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eip) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_route53_zone.route53_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_tag_map"></a> [additional\_tag\_map](#input\_additional\_tag\_map) | Additional key-value pairs to add to each map in `tags_as_list_of_maps`. Not added to `tags` or `id`.<br/>This is for some rare cases where resources want additional configuration of tags<br/>and therefore take a list of maps with tag key, value, and additional configuration. | `map(string)` | `{}` | no |
| <a name="input_alb_names"></a> [alb\_names](#input\_alb\_names) | list of ALB names which will be protected with AWS Shield Advanced | `list(string)` | `[]` | no |
| <a name="input_alb_protection_enabled"></a> [alb\_protection\_enabled](#input\_alb\_protection\_enabled) | Enable ALB protection. By default, ALB names are read from the EKS cluster ALB control group | `bool` | `false` | no |
| <a name="input_attributes"></a> [attributes](#input\_attributes) | ID element. Additional attributes (e.g. `workers` or `cluster`) to add to `id`,<br/>in the order they appear in the list. New attributes are appended to the<br/>end of the list. The elements of the list are joined by the `delimiter`<br/>and treated as a single ID element. | `list(string)` | `[]` | no |
| <a name="input_cloudfront_distribution_ids"></a> [cloudfront\_distribution\_ids](#input\_cloudfront\_distribution\_ids) | list of CloudFront Distribution IDs which will be protected with AWS Shield Advanced | `list(string)` | `[]` | no |
| <a name="input_context"></a> [context](#input\_context) | Single object for setting entire context at once.<br/>See description of individual variables for details.<br/>Leave string and numeric variables as `null` to use default value.<br/>Individual variable settings (non-null) override settings in context object,<br/>except for attributes, tags, and additional\_tag\_map, which are merged. | `any` | <pre>{<br/>  "additional_tag_map": {},<br/>  "attributes": [],<br/>  "delimiter": null,<br/>  "descriptor_formats": {},<br/>  "enabled": true,<br/>  "environment": null,<br/>  "id_length_limit": null,<br/>  "label_key_case": null,<br/>  "label_order": [],<br/>  "label_value_case": null,<br/>  "labels_as_tags": [<br/>    "unset"<br/>  ],<br/>  "name": null,<br/>  "namespace": null,<br/>  "regex_replace_chars": null,<br/>  "stage": null,<br/>  "tags": {},<br/>  "tenant": null<br/>}</pre> | no |
| <a name="input_delimiter"></a> [delimiter](#input\_delimiter) | Delimiter to be used between ID elements.<br/>Defaults to `-` (hyphen). Set to `""` to use no delimiter at all. | `string` | `null` | no |
| <a name="input_descriptor_formats"></a> [descriptor\_formats](#input\_descriptor\_formats) | Describe additional descriptors to be output in the `descriptors` output map.<br/>Map of maps. Keys are names of descriptors. Values are maps of the form<br/>`{<br/>   format = string<br/>   labels = list(string)<br/>}`<br/>(Type is `any` so the map values can later be enhanced to provide additional options.)<br/>`format` is a Terraform format string to be passed to the `format()` function.<br/>`labels` is a list of labels, in order, to pass to `format()` function.<br/>Label values will be normalized before being passed to `format()` so they will be<br/>identical to how they appear in `id`.<br/>Default is `{}` (`descriptors` output will be empty). | `any` | `{}` | no |
| <a name="input_eips"></a> [eips](#input\_eips) | List of Elastic IPs which will be protected with AWS Shield Advanced | `list(string)` | `[]` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | Set to false to prevent the module from creating any resources | `bool` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | ID element. Usually used for region e.g. 'uw2', 'us-west-2', OR role 'prod', 'staging', 'dev', 'UAT' | `string` | `null` | no |
| <a name="input_id_length_limit"></a> [id\_length\_limit](#input\_id\_length\_limit) | Limit `id` to this many characters (minimum 6).<br/>Set to `0` for unlimited length.<br/>Set to `null` for keep the existing setting, which defaults to `0`.<br/>Does not affect `id_full`. | `number` | `null` | no |
| <a name="input_label_key_case"></a> [label\_key\_case](#input\_label\_key\_case) | Controls the letter case of the `tags` keys (label names) for tags generated by this module.<br/>Does not affect keys of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper`.<br/>Default value: `title`. | `string` | `null` | no |
| <a name="input_label_order"></a> [label\_order](#input\_label\_order) | The order in which the labels (ID elements) appear in the `id`.<br/>Defaults to ["namespace", "environment", "stage", "name", "attributes"].<br/>You can omit any of the 6 labels ("tenant" is the 6th), but at least one must be present. | `list(string)` | `null` | no |
| <a name="input_label_value_case"></a> [label\_value\_case](#input\_label\_value\_case) | Controls the letter case of ID elements (labels) as included in `id`,<br/>set as tag values, and output by this module individually.<br/>Does not affect values of tags passed in via the `tags` input.<br/>Possible values: `lower`, `title`, `upper` and `none` (no transformation).<br/>Set this to `title` and set `delimiter` to `""` to yield Pascal Case IDs.<br/>Default value: `lower`. | `string` | `null` | no |
| <a name="input_labels_as_tags"></a> [labels\_as\_tags](#input\_labels\_as\_tags) | Set of labels (ID elements) to include as tags in the `tags` output.<br/>Default is to include all labels.<br/>Tags with empty values will not be included in the `tags` output.<br/>Set to `[]` to suppress all generated tags.<br/>**Notes:**<br/>  The value of the `name` tag, if included, will be the `id`, not the `name`.<br/>  Unlike other `null-label` inputs, the initial setting of `labels_as_tags` cannot be<br/>  changed in later chained modules. Attempts to change it will be silently ignored. | `set(string)` | <pre>[<br/>  "default"<br/>]</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | ID element. Usually the component or solution name, e.g. 'app' or 'jenkins'.<br/>This is the only ID element not also included as a `tag`.<br/>The "name" tag is set to the full `id` string. There is no tag with the value of the `name` input. | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | ID element. Usually an abbreviation of your organization name, e.g. 'eg' or 'cp', to help ensure generated IDs are globally unique | `string` | `null` | no |
| <a name="input_regex_replace_chars"></a> [regex\_replace\_chars](#input\_regex\_replace\_chars) | Terraform regular expression (regex) string.<br/>Characters matching the regex will be removed from the ID elements.<br/>If not set, `"/[^a-zA-Z0-9-]/"` is used to remove all characters other than hyphens, letters and digits. | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS Region | `string` | n/a | yes |
| <a name="input_route53_zone_names"></a> [route53\_zone\_names](#input\_route53\_zone\_names) | List of Route53 Hosted Zone names which will be protected with AWS Shield Advanced | `list(string)` | `[]` | no |
| <a name="input_stage"></a> [stage](#input\_stage) | ID element. Usually used to indicate role, e.g. 'prod', 'staging', 'source', 'build', 'test', 'deploy', 'release' | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags (e.g. `{'BusinessUnit': 'XYZ'}`).<br/>Neither the tag keys nor the tag values will be modified by this module. | `map(string)` | `{}` | no |
| <a name="input_tenant"></a> [tenant](#input\_tenant) | ID element \_(Rarely used, not included by default)\_. A customer identifier, indicating who this instance of a resource is for | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_load_balancer_protections"></a> [application\_load\_balancer\_protections](#output\_application\_load\_balancer\_protections) | AWS Shield Advanced Protections for ALBs |
| <a name="output_cloudfront_distribution_protections"></a> [cloudfront\_distribution\_protections](#output\_cloudfront\_distribution\_protections) | AWS Shield Advanced Protections for CloudFront Distributions |
| <a name="output_elastic_ip_protections"></a> [elastic\_ip\_protections](#output\_elastic\_ip\_protections) | AWS Shield Advanced Protections for Elastic IPs |
| <a name="output_route53_hosted_zone_protections"></a> [route53\_hosted\_zone\_protections](#output\_route53\_hosted\_zone\_protections) | AWS Shield Advanced Protections for Route53 Hosted Zones |
<!-- markdownlint-restore -->



## References


- [AWS Shield Documentation](https://docs.aws.amazon.com/shield/) - Official AWS Shield documentation

- [AWS Shield Advanced Developer Guide](https://docs.aws.amazon.com/waf/latest/developerguide/shield-chapter.html) - Comprehensive guide for AWS Shield Advanced features and configuration

- [Subscribing to AWS Shield Advanced](https://docs.aws.amazon.com/waf/latest/developerguide/enable-ddos-prem.html) - Step-by-step instructions for subscribing to Shield Advanced

- [AWS Shield Pricing](https://aws.amazon.com/shield/pricing/) - Pricing details for AWS Shield Advanced ($3,000/month per organization)

- [DDoS Response Team (DRT) Support](https://docs.aws.amazon.com/waf/latest/developerguide/ddos-srt-support.html) - How to engage AWS DDoS Response Team during attacks

- [AWS Best Practices for DDoS Resiliency](https://docs.aws.amazon.com/whitepapers/latest/aws-best-practices-ddos-resiliency/welcome.html) - AWS whitepaper on DDoS mitigation best practices

- [Terraform aws_shield_protection Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/shield_protection) - Terraform documentation for the aws_shield_protection resource

- [cloudposse-terraform-components](https://github.com/orgs/cloudposse-terraform-components/repositories) - Cloud Posse's upstream component repository




[<img src="https://cloudposse.com/logo-300x69.svg" height="32" align="right"/>](https://cpco.io/homepage?utm_source=github&utm_medium=readme&utm_campaign=cloudposse-terraform-components/aws-shield&utm_content=)


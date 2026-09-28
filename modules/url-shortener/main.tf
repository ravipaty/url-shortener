locals {
  name = "${var.project}-${var.environment}"
}

module "table" {
  source                 = "../dynamodb-table"
  name                   = "${local.name}-links"
  point_in_time_recovery = var.environment == "prod"
}

module "api" {
  source     = "../lambda-api"
  name       = local.name
  source_dir = var.lambda_source_dir
  table_name = module.table.name
  table_arn  = module.table.arn
}

module "site" {
  source = "../static-site"
  name   = local.name
  index_html = templatefile(var.index_template_path, {
    api_url     = module.api.api_url
    environment = var.environment
  })
}

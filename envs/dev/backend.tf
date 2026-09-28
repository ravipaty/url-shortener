terraform {
  # bucket is passed at init time so it never has to be committed:
  #   terraform init -backend-config="bucket=<TF_STATE_BUCKET>"
  backend "s3" {
    key          = "url-shortener/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

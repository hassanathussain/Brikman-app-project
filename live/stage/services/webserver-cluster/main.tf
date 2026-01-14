module "webserver_cluster" {
  source                 = "../../../../modules/services/webserver-cluster"
  cluster_name           = "webservers-stage"
  db_remote_state_bucket = "my-terraform-state-bucket-76474" # Replace with your S3 bucket
  db_remote_state_key    = "terraform/stage/services/terraform.tfstate"
  instance_type          = "t2.micro"
  min_size               = 2
  max_size               = 2
  server_port            = 80
}

variable "region" {
  description = "aws region to deploy the resource"
  default = "ap-southeast-1"
}

variable "ami_id" {
  description = "Image for instance"
  type        = map
  default     = {
    ap-southeast-1 = "ami-0532913178263be11"
    ap-southeast-2 = "ami-06259b63260eddc13"
    ap-norteast-1 = "ami-0126975fb247bf2e7"
  }
}

variable "instance_type" {
  description = "Type of instance"
  default     = "t3.medium"
}

variable "key_name" {
  description = "kay name to connect to the server"
  default     = "terraform"
}

variable "vpc_id" {
  description = "vpc id for security group"
  default     = "vpc-049209c28c1d4e603"
}

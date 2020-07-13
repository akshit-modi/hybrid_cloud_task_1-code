provider "aws" {
    region = "ap-south-1"
    profile = "Akshit"
}


resource "aws_instance" "Cloud-1" {
    ami           = "ami-052c08d70def0ac62"
    instance_type = "t2.micro"
    key_name = "Cloud-project"
    security_groups = [ "Cloud-1" ]


    connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = file("C:/Users/admin/Downloads/Cloud-project.pem")
        host     = aws_instance.Cloud-1.public_ip
    }
    provisioner "remote-exec" {
        inline = [
          "sudo yum install httpd git -y",
          "sudo systemctl start httpd",
          "sudo systemctl enable httpd",
        ]
    }
    tags = {
        Name = "webos"
    }
}



resource "aws_ebs_volume" "Cloud-ebs" {

    depends_on = [
        aws_instance.Cloud-1,
    ]
    availability_zone = aws_instance.Cloud-1.availability_zone
    size              = 1
    tags = {
        Name = "WebServer_ebs"
    }
}

resource "aws_volume_attachment" "attach_ebs_os" {

    depends_on = [
        aws_ebs_volume.Cloud-ebs,
    ]
    device_name = "/dev/sde"
    volume_id   = "${aws_ebs_volume.Cloud-ebs.id}"
    instance_id = "${aws_instance.Cloud-1.id}"
    force_detach = true
}


output "webos_ip" {
  value = aws_instance.Cloud-1.public_ip
}


resource "null_resource" "get_ip"  {

    depends_on = [
        aws_volume_attachment.attach_ebs_os,
    ]
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.Cloud-1.public_ip} > public_ip.txt"
  	}
}



resource "null_resource" "mount_ebs"  {
    
    depends_on = [
        aws_volume_attachment.attach_ebs_os,
    ]

    connection {
        type     = "ssh"
        user     = "ec2-user"
        private_key = file("C:/Users/admin/Downloads/Cloud-project.pem")
        host     = aws_instance.Cloud-1.public_ip
    }
    provisioner "remote-exec" {
        inline = [
          "sudo mkfs.ext4  /dev/xvde",
          "sudo mount  /dev/xvde  /var/www/html",
          "sudo rm -rf /var/www/html/*",
          "sudo git clone https://github.com/akshit0704/Hybrid_cloud_task_1.git /var/www/html/",
          "sudo rm -rf /etc/httpd/conf.d/welcome.conf"
        ]
    }
}


resource "aws_s3_bucket" "akshitfirstbucket" {

    depends_on = [
        null_resource.mount_ebs,
    ]
  bucket = "akshitfirstbucket"
  acl    = "private"

  tags = {
    Name        = "cloud-bucket"
  }
}

resource "aws_s3_bucket_object" "object" {

   depends_on = [
        aws_s3_bucket.akshitfirstbucket,
    ]
  key        = "akshitfirstbucket"
  bucket     = "${aws_s3_bucket.akshitfirstbucket.id}"
  source     = "C:/Users/admin/Desktop/Vishwakarma/Parth/New folder/nss.jpg"
  etag = filemd5("C:/Users/admin/Desktop/Vishwakarma/Parth/New folder/nss.jpg")
  acl = "public-read-write"
}


resource "aws_s3_bucket_public_access_block" "allow_public_access" {

    depends_on = [
        aws_s3_bucket_object.object,
    ]
  bucket = "${aws_s3_bucket.akshitfirstbucket.id}"

  block_public_acls   = false
  block_public_policy = false
}



locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {

    depends_on = [
        aws_s3_bucket_public_access_block.allow_public_access,
    ]
  origin {
    domain_name = "${aws_s3_bucket.akshitfirstbucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      #restriction_type = "whitelist"
   #   locations        = ["US", "CA", "GB", "DE"]
    }
  }

  tags = {
    Name = "S3-distribution"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "mycf" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}
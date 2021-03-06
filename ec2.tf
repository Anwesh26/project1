provider "aws" {
	region = "ap-south-1"
	profile = "anwesh"
}

resource "aws_instance" "myos1" {
	ami           = "ami-005956c5f0f757d37"
	instance_type = "t2.micro"
	key_name      = "keycloudclass"
	security_groups = ["${aws_security_group.mygroup1	.name}"]

	connection {
		type        = "ssh"
		user        = "ec2-user"
		private_key = file(C:\Users\Anchit\Downloads\keycloudclass.pem")
		host        = aws_instance.myos1.public_ip
	}
	
	provisioner "remote-exec" {
		inline = [
			"sudo yum install http php git -y",
			"sudo service httpd start",
			"sudo service httpd status",
		]
	}
	
	tags = {
		Name = "myos1"
	}
}


resource "aws_security_group" "mygroup1" {
	name        = "MYGROUP"
	description = "security group for web server"
	vpc_id      = "vpc-58435d30"
  	ingress {
    		from_port   = 443
	    	to_port     = 443
    		protocol    = "tcp"
    		cidr_blocks = ["0.0.0.0/0"]
  	}

  	ingress {
    		from_port   = 80
    		to_port     = 80
    		protocol    = "tcp"
    		cidr_blocks = ["0.0.0.0/0"]
  	}

  	ingress {
    		from_port   = 22
    		to_port     = 22
    		protocol    = "tcp"
    		cidr_blocks = ["0.0.0.0/0"]
  	}

  	egress {
    		from_port   = 443
    		to_port     = 443
    		protocol    = "tcp"
    		cidr_blocks = ["0.0.0.0/0"]
  	}

	egress {
    		from_port   = 80
		to_port     = 80
    		protocol    = "tcp"
    		cidr_blocks = ["0.0.0.0/0"]
  	}

 	egress {
    		from_port   = 22
    		to_port     = 22
    		protocol    = "tcp"
    		cidr_blocks = ["0.0.0.0/0"]
  	}
}


resource "aws_ebs_volume" "ebs_volume" {
  	availability_zone = aws_instance.myos1.availability_zone
  	size              = 1

  	tags = {
    		Name = "vol_1"
  	}
}


resource "aws_volume_attachment" "ebs_att" {
  	device_name  = "/dev/sdh"
  	volume_id    = "${aws_ebs_volume.ebs_volume.id}"
  	instance_id  = "${aws_instance.myos1.id}"
	force_detach = true
	depends_on = [
		aws_ebs_volume.ebs_volume,
		aws_instance.myos1
	]
}


output "myos1_ip" {
  value = aws_instance.myos1.public_ip
}


resource "null_resource" "nulllocal1"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.myos1.public_ip} > myos1_ip.txt"
  	}
}


resource "null_resource" "nullremote1"  {
	depends_on = [
    		aws_volume_attachment.ebs_att,
  	]

 	connection {
    		type     = "ssh"
    		user     = "ec2-user"
    		private_key = file("C:/Users/Anchit/Downloads/keycloudclass.pem")
    		host     = aws_instance.myos1.public_ip
  	}
 
	provisioner "remote-exec" {
    		inline = [
      			"sudo mkfs.ext4  /dev/xvdh",
      			"sudo mount  /dev/xvdh  /var/www/html",
      			"sudo rm -rf /var/www/html/ *",
      			"sudo git clone https://github.com/Anwesh26/terraform-project1.git /var/www/html",
        	]
    	}
}


resource "aws_s3_bucket" "bucket" {
    
  	depends_on = [
    		aws_volume_attachment.ebs_att,
  	]

 	bucket = "mytf1-bucket"
  	acl    = "public-read"

 	provisioner "local-exec" {
     		command = "git clone https://github.com/Anwesh26/project1 images"
      	}

 	provisioner "local-exec" {
        	when = destroy
        	command = "rm -rf images"
       }
}


resource "aws_s3_bucket_object" "s3bucket" {
  	bucket = aws_s3_bucket.bucket1.bucket
  	key    = "indian_army.jpg"
  	source = "images/indian_army.jpg"
  	content_type = "image/jpg"
  	acl = "public-read"
  	depends_on = [	
  	    	aws_s3_bucket.bucket1
  	]
}


locals {
  	s3_origin_id = "S3-${aws_s3_bucket.bucket1.bucket}"
}


resource "aws_cloudfront_distribution" "cloudfront1" {  
    	origin {
    		domain_name = "${aws_s3_bucket.bucket1.bucket_regional_domain_name}"
    		origin_id   = "locals.s3_origin_id"
              	custom_origin_config {
        		http_port = 80
        		https_port = 80
		        origin_protocol_policy = "match-viewer"
        		origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
	       }
	}

	enabled = true
 	is_ipv6_enabled = true
	
	default_cache_behavior {
	    	allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    		cached_methods   = ["GET", "HEAD"]
    		target_origin_id = "locals.s3_origin_id"

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
     		}
   	}

  	viewer_certificate {
    		cloudfront_default_certificate = true
  	}
	
	connection {
    		type     = "ssh"
    		user     = "ec2-user"
    		private_key = file("C:/Users/Anchit/Downloads/keycloudclass.pem")
    		host     = aws_instance.myos1.public_ip
     	}
  
  	provisioner "remote-exec" {
      		inline = [
          		"sudo su << EOF",
          		"echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.s3object1.key}'width='600' height='600'>\" >> /var/www/html/myself.html",
          		"EOF",
      		]
    	}  
}


resource "null_resource" "nulllocal2"  {
	depends_on = [
    		null_resource.nullremote1,
  	]

	provisioner "local-exec" {
		command = " start chrome  ${aws_instance.myos1.public_ip}/web.html"
  	}
}




# This module generates a self-signed TLS certificate
# and configuration file for use in the MSR4 installation.

# 1. Generate OpenSSL configuration file using a template
resource "local_file" "openssl_conf" {
  content = templatefile("${path.root}/templates/openssl.conf.tpl", {
    msr_common_name = var.msr_common_name
  })
  filename = "${var.cert_path}/${var.cert_conf_name}"
}

# 2. Generate certficate files using config file in tsl_cert directory
resource "null_resource" "generate_cert" {
  depends_on = [local_file.openssl_conf]

  provisioner "local-exec" {
    command = <<EOT
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout "${var.cert_path}/${var.cert_key_name}" \
      -out "${var.cert_path}/${var.cert_crt_name}" \
      -config "${var.cert_path}/${var.cert_conf_name}" \
      -extensions v3_ext
    EOT
  }
}

# 3. Clean up the certificate files on destroy
resource "null_resource" "cleanup_tls_files" {
  triggers = {
    cleanup_dir = "${path.root}/tls_cert"
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<EOT
      echo "Cleaning up TLS certificate files in ${self.triggers.cleanup_dir}..."
      rm -f "${self.triggers.cleanup_dir}"/*
      rmdir "${self.triggers.cleanup_dir}" || echo "Directory not empty or not found"
    EOT
  }
}

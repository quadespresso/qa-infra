resource "aws_efs_file_system" "cluster" {
    encrypted        = "true"
    tags             = var.globals.tags
}

resource "aws_efs_mount_target" "az" {
    count           = var.globals.subnet_count
    file_system_id  = "${aws_efs_file_system.cluster.id}"
    subnet_id       = var.globals.subnet_ids[count.index]
    security_groups = [var.globals.security_group_id]
}

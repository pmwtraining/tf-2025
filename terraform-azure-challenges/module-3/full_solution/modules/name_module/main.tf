variable "yourname" {}
variable "location" {}

output "nameconv" {
  value = join("-",[
    "bctf",
    var.yourname,
    var.location])
}
locals {
  # convert input set into a map by assuming name type combination is unique
  # techically we could include r.records[0] in the key to ensure uniqueness,
  # but then the aws api will complain - it expects all records for a particular
  # name/type to be grouped into a single array!
  records = {
    for r in var.records : "${r.name} ${r.type}" => r
  }
}

resource "aws_route53_record" "records" {
  zone_id  = var.zone.id
  for_each = local.records

  name    = each.value.name
  type    = each.value.type
  ttl     = var.default_ttl
  records = each.value.records
}

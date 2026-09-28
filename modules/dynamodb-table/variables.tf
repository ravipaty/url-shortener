variable "name" {
  description = "Table name."
  type        = string
}

variable "hash_key" {
  description = "Partition key attribute name (string)."
  type        = string
  default     = "code"
}

variable "point_in_time_recovery" {
  description = "Enable PITR backups (small extra cost; usually prod only)."
  type        = bool
  default     = false
}

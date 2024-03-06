variable "folder_id" {
  type = string
  description = "Folder ID in which to create all application admin projects"
}

variable "envs" {
  type = map(any)
}
package com.teven.data.customer

import org.jetbrains.exposed.dao.id.IntIdTable

object Customers : IntIdTable() {
  val name = varchar("name", 255)
  val contactInformation = varchar("contact_information", 255)
}

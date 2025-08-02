package com.teven.data.customer

import org.jetbrains.exposed.sql.Table

object Customers : Table() {
  val id = integer("id").autoIncrement()
  val name = varchar("name", 255)
  val contactInformation = varchar("contact_information", 255)

  override val primaryKey = PrimaryKey(id)
}
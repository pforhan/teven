
package com.teven.app.di

import com.teven.data.customer.CustomerDao
import com.teven.data.event.EventDao
import com.teven.data.inventory.InventoryDao
import com.teven.data.report.ReportDao
import com.teven.data.role.RoleDao
import com.teven.data.user.UserDao
import com.teven.service.customer.CustomerService
import com.teven.service.event.EventService
import com.teven.service.inventory.InventoryService
import com.teven.service.report.ReportService
import com.teven.service.role.RoleService
import com.teven.service.user.UserService
import org.koin.dsl.module

val appModule = module {
    single { UserDao() }
    single { UserService(get()) }
    single { EventDao() }
    single { EventService(get()) }
    single { CustomerDao() }
    single { CustomerService(get()) }
    single { InventoryDao() }
    single { InventoryService(get()) }
    single { ReportDao() }
    single { ReportService(get()) }
    single { RoleDao() }
    single { RoleService(get()) }
}

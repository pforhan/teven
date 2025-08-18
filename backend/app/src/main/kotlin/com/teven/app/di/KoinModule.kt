package com.teven.app.di

import com.teven.auth.AuthServiceImpl
import com.teven.core.service.AuthService
import com.teven.core.service.RoleService
import com.teven.core.service.UserService
import com.teven.data.customer.CustomerDao
import com.teven.data.event.EventDao
import com.teven.data.inventory.InventoryDao
import com.teven.data.organization.OrganizationDao
import com.teven.data.report.ReportDao
import com.teven.data.role.RoleDao
import com.teven.data.user.UserDao
import com.teven.service.customer.CustomerService
import com.teven.service.event.EventService
import com.teven.service.inventory.InventoryService
import com.teven.service.organization.OrganizationService
import com.teven.service.report.ReportService
import com.teven.service.role.RoleServiceImpl
import com.teven.service.user.UserServiceImpl
import org.koin.dsl.module

val appModule = module {
  single { UserDao() }
  
  single<UserService> { UserServiceImpl(get(), get(), get()) }
  single<AuthService> { AuthServiceImpl(get(), get()) }
  single<RoleService> { RoleServiceImpl(get()) }
  single { EventDao() }
  single { EventService(get()) }
  single { CustomerDao() }
  single { CustomerService(get()) }
  single { InventoryDao() }
  single { InventoryService(get()) }
  single { ReportDao() }
  single { ReportService(get()) }
  single { RoleDao() }
  single { OrganizationDao() }
  single { OrganizationService(get(), get()) }
}

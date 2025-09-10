package com.teven.app.di

import com.teven.app.InitialSetup
import com.teven.auth.ApplicationAuth
import com.teven.auth.AuthServiceImpl
import com.teven.core.security.JwtConfig
import com.teven.core.service.AuthService
import com.teven.core.service.PermissionService
import com.teven.core.service.RoleService
import com.teven.core.service.UserService
import com.teven.data.event.EventDao
import com.teven.data.inventory.InventoryDao
import com.teven.data.organization.OrganizationDao
import com.teven.data.report.ReportDao
import com.teven.data.role.RoleDao
import com.teven.data.user.UserDao
import com.teven.service.event.EventService
import com.teven.service.inventory.InventoryService
import com.teven.service.organization.OrganizationService
import com.teven.service.permission.PermissionServiceImpl
import com.teven.service.report.ReportService
import com.teven.service.role.RoleServiceImpl
import com.teven.service.user.UserServiceImpl
import org.koin.dsl.module

val appModule = module {
  single { UserDao() }

  single<UserService> { UserServiceImpl(get(), get(), get()) }
  single<AuthService> { AuthServiceImpl(get(), get(), get()) }
  single<RoleService> { RoleServiceImpl(get()) }
  single<PermissionService> { PermissionServiceImpl(get()) }
  single { EventDao() }
  single { InventoryDao() }
  single { EventService(get()) }
  single { InventoryService(get()) }
  single { ReportDao() }
  single { ReportService(get()) }
  single { RoleDao() }
  single { OrganizationDao() }
  single { OrganizationService(get(), get()) }
  single {
    JwtConfig(
      secret = System.getenv("JWT_SECRET")
        ?: throw IllegalArgumentException("JWT_SECRET environment variable not set"),
      issuer = System.getenv("JWT_ISSUER")
        ?: throw IllegalArgumentException("JWT_ISSUER environment variable not set"),
      audience = System.getenv("JWT_AUDIENCE")
        ?: throw IllegalArgumentException("JWT_AUDIENCE environment variable not set"),
      expirationTimeMillis = System.getenv("JWT_EXPIRATION_MILLIS")?.toLongOrNull()
        ?: throw IllegalArgumentException("JWT_EXPIRATION_MILLIS environment variable not set or invalid")
    )
  }
  single { InitialSetup(get(), get(), get()) }
  single { ApplicationAuth(get()) }
}
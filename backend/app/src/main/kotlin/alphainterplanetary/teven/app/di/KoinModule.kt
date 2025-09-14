package alphainterplanetary.teven.app.di

import alphainterplanetary.teven.app.InitialSetup
import alphainterplanetary.teven.auth.ApplicationAuth
import alphainterplanetary.teven.auth.AuthServiceImpl
import alphainterplanetary.teven.core.security.JwtConfig
import alphainterplanetary.teven.core.service.AuthService
import alphainterplanetary.teven.core.service.PermissionService
import alphainterplanetary.teven.core.service.RoleService
import alphainterplanetary.teven.core.service.UserService
import alphainterplanetary.teven.data.customer.CustomerDao
import alphainterplanetary.teven.data.event.EventDao
import alphainterplanetary.teven.data.inventory.InventoryDao
import alphainterplanetary.teven.data.organization.OrganizationDao
import alphainterplanetary.teven.data.report.ReportDao
import alphainterplanetary.teven.data.role.RoleDao
import alphainterplanetary.teven.data.user.UserDao
import alphainterplanetary.teven.service.customer.CustomerService
import alphainterplanetary.teven.service.event.EventService
import alphainterplanetary.teven.service.inventory.InventoryService
import alphainterplanetary.teven.service.organization.OrganizationService
import alphainterplanetary.teven.service.permission.PermissionServiceImpl
import alphainterplanetary.teven.service.report.ReportService
import alphainterplanetary.teven.service.role.RoleServiceImpl
import alphainterplanetary.teven.service.user.UserServiceImpl
import org.koin.dsl.module

val appModule = module {
  single { UserDao() }

  single<UserService> { UserServiceImpl(get(), get()) }
  single<AuthService> { AuthServiceImpl(get(), get(), get()) }
  single<RoleService> { RoleServiceImpl(get()) }
  single<PermissionService> { PermissionServiceImpl(get()) }
  single { EventDao(get()) }
  single { InventoryDao() }
  single { EventService(get()) }
  single { InventoryService(get()) }
  single { ReportDao() }
  single { ReportService(get()) }
  single { RoleDao() }
  single { OrganizationDao() }
  single { OrganizationService(get(), get()) }
  single { CustomerDao() }
  single { CustomerService(get()) }
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
  single { ApplicationAuth(get(), get()) }
}
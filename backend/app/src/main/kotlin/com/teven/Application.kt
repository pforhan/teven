package com.teven

import com.teven.app.configureRouting
import com.teven.app.di.appModule
import com.teven.app.setupSuperAdmin
import com.teven.data.DatabaseFactory
import com.teven.service.role.RoleService
import com.teven.service.user.UserService
import io.ktor.serialization.kotlinx.json.json
import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.engine.embeddedServer
import io.ktor.server.netty.Netty
import io.ktor.server.plugins.contentnegotiation.ContentNegotiation
import org.koin.ktor.ext.inject
import org.koin.ktor.plugin.Koin

fun main() {
  embeddedServer(Netty, port = 8080, host = "0.0.0.0", module = Application::module)
    .start(wait = true)
}

fun Application.module() {
  DatabaseFactory.init()
  install(ContentNegotiation) {
    json()
  }
  install(Koin) {
    modules(appModule)
  }

  val userService by inject<UserService>()
  val roleService by inject<RoleService>()
  setupSuperAdmin(userService, roleService)

  configureRouting()
}



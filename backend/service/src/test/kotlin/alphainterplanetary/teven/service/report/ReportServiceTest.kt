package alphainterplanetary.teven.service.report

import alphainterplanetary.teven.api.model.report.InventoryUsageReportResponse
import alphainterplanetary.teven.api.model.report.StaffHoursReportRequest
import alphainterplanetary.teven.api.model.report.StaffHoursReportResponse
import alphainterplanetary.teven.core.BadRequestException
import alphainterplanetary.teven.core.security.AuthContext
import alphainterplanetary.teven.core.security.Permission
import alphainterplanetary.teven.data.report.ReportDao
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import kotlinx.coroutines.runBlocking
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ReportServiceTest {

  private val reportDao: ReportDao = mockk()
  private val reportService = ReportService(reportDao)

  private fun authContext(organizationId: Int, permissions: Set<Permission>) =
    AuthContext(userId = 10, organizationId = organizationId, permissions = permissions)

  private fun staffHoursRequest(organizationId: Int) = StaffHoursReportRequest(
    organizationId = organizationId,
    startDate = "2026-01-01",
    endDate = "2026-01-31",
    timezone = "UTC",
  )

  @Test
  fun `staff hours allows an org-scoped caller to request their own organization`() = runBlocking {
    val expected = listOf(StaffHoursReportResponse(1, "ada", "Ada", 8))
    coEvery { reportDao.getStaffHoursReport(any(), 5) } returns expected

    val result = reportService.getStaffHoursReport(
      authContext(5, setOf(Permission.VIEW_REPORTS_ORGANIZATION)),
      staffHoursRequest(5),
    )

    assertEquals(expected, result)
    coVerify { reportDao.getStaffHoursReport(any(), 5) }
  }

  @Test
  fun `staff hours rejects an org-scoped caller requesting another organization`() = runBlocking {
    val exception = runCatching {
      reportService.getStaffHoursReport(
        authContext(5, setOf(Permission.VIEW_REPORTS_ORGANIZATION)),
        staffHoursRequest(9),
      )
    }.exceptionOrNull()

    assertNotNull(exception)
    assertTrue(exception is IllegalAccessException)
    coVerify(exactly = 0) { reportDao.getStaffHoursReport(any(), any()) }
  }

  @Test
  fun `staff hours allows a global caller to request another organization`() = runBlocking {
    val expected = listOf(StaffHoursReportResponse(1, "ada", "Ada", 8))
    coEvery { reportDao.getStaffHoursReport(any(), 9) } returns expected

    val result = reportService.getStaffHoursReport(
      authContext(5, setOf(Permission.VIEW_REPORTS_ORGANIZATION, Permission.VIEW_REPORTS_GLOBAL)),
      staffHoursRequest(9),
    )

    assertEquals(expected, result)
    coVerify { reportDao.getStaffHoursReport(any(), 9) }
  }

  @Test
  fun `staff hours rejects an unknown time zone before authorization side effects`() = runBlocking {
    val exception = runCatching {
      reportService.getStaffHoursReport(
        authContext(5, setOf(Permission.VIEW_REPORTS_ORGANIZATION)),
        StaffHoursReportRequest(5, "2026-01-01", "2026-01-31", "Mars/Olympus"),
      )
    }.exceptionOrNull()

    assertNotNull(exception)
    assertEquals(BadRequestException::class.java, exception!!.javaClass)
  }

  @Test
  fun `staff hours rejects an invalid date`() = runBlocking {
    coEvery { reportDao.getStaffHoursReport(any(), any()) } throws java.time.format.DateTimeParseException("bad", "nope", 0)

    val exception = runCatching {
      reportService.getStaffHoursReport(
        authContext(5, setOf(Permission.VIEW_REPORTS_ORGANIZATION)),
        StaffHoursReportRequest(5, "not-a-date", "2026-01-31", "UTC"),
      )
    }.exceptionOrNull()

    assertNotNull(exception)
    assertEquals(BadRequestException::class.java, exception!!.javaClass)
  }

  @Test
  fun `inventory usage allows an org-scoped caller to request their own organization`() = runBlocking {
    val expected = listOf(InventoryUsageReportResponse(1, "Chairs", 3))
    coEvery { reportDao.getInventoryUsageReport(5) } returns expected

    val result = reportService.getInventoryUsageReport(
      authContext(5, setOf(Permission.VIEW_REPORTS_ORGANIZATION)),
      5,
    )

    assertEquals(expected, result)
    coVerify { reportDao.getInventoryUsageReport(5) }
  }

  @Test
  fun `inventory usage rejects an org-scoped caller requesting another organization`() = runBlocking {
    val exception = runCatching {
      reportService.getInventoryUsageReport(
        authContext(5, setOf(Permission.VIEW_REPORTS_ORGANIZATION)),
        9,
      )
    }.exceptionOrNull()

    assertNotNull(exception)
    assertTrue(exception is IllegalAccessException)
    coVerify(exactly = 0) { reportDao.getInventoryUsageReport(any()) }
  }

  @Test
  fun `inventory usage allows a global caller to request another organization`() = runBlocking {
    val expected = listOf(InventoryUsageReportResponse(1, "Chairs", 3))
    coEvery { reportDao.getInventoryUsageReport(9) } returns expected

    val result = reportService.getInventoryUsageReport(
      authContext(5, setOf(Permission.VIEW_REPORTS_ORGANIZATION, Permission.VIEW_REPORTS_GLOBAL)),
      9,
    )

    assertEquals(expected, result)
    coVerify { reportDao.getInventoryUsageReport(9) }
  }
}

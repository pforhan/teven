package alphainterplanetary.teven.data.user

import alphainterplanetary.teven.api.model.auth.StaffDetails as StaffDetailsResponse
import alphainterplanetary.teven.api.model.user.UpdateStaffDetails
import alphainterplanetary.teven.data.dbQuery
import alphainterplanetary.teven.data.report.StaffHours
import java.time.LocalDate
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.jetbrains.exposed.v1.core.ResultRow
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.core.sum
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.select
import org.jetbrains.exposed.v1.jdbc.selectAll
import org.jetbrains.exposed.v1.jdbc.update

data class StaffDetailsRecord(
  val contactInformation: String,
  val skills: List<String>,
  val phoneNumber: String,
  val dateOfBirth: LocalDate?,
)

class StaffDetailsDao {
  private val json = Json

  private fun toRecord(row: ResultRow): StaffDetailsRecord {
    val skillsRaw = row[StaffDetails.skills]
    val skills = runCatching { json.decodeFromString<List<String>>(skillsRaw) }
      .getOrDefault(emptyList())
    return StaffDetailsRecord(
      contactInformation = row[StaffDetails.contactInformation],
      skills = skills,
      phoneNumber = row[StaffDetails.phoneNumber],
      dateOfBirth = row[StaffDetails.dateOfBirth],
    )
  }

  private suspend fun getRecordByUserId(userId: Int): StaffDetailsRecord? = dbQuery {
    StaffDetails.selectAll()
      .where { StaffDetails.userId eq userId }
      .map { toRecord(it) }
      .singleOrNull()
  }

  private suspend fun getTotalHoursWorked(userId: Int): Int = dbQuery {
    val total = StaffHours.hoursWorked.sum()
    StaffHours.select(StaffHours.userId, total)
      .where { StaffHours.userId eq userId }
      .groupBy(StaffHours.userId)
      .firstOrNull()
      ?.get(total) ?: 0
  }

  suspend fun getByUserId(userId: Int): StaffDetailsResponse? {
    val record = getRecordByUserId(userId) ?: return null
    val hoursWorked = getTotalHoursWorked(userId)
    return StaffDetailsResponse(
      contactInformation = record.contactInformation,
      skills = record.skills,
      hoursWorked = hoursWorked,
      phoneNumber = record.phoneNumber,
      dateOfBirth = record.dateOfBirth?.toString() ?: "",
    )
  }

  suspend fun upsert(userId: Int, update: UpdateStaffDetails) {
    dbQuery {
      val existing = StaffDetails.selectAll()
        .where { StaffDetails.userId eq userId }
        .map { toRecord(it) }
        .singleOrNull()

      val contactInformation = update.contactInformation ?: existing?.contactInformation ?: ""
      val phoneNumber = update.phoneNumber ?: existing?.phoneNumber ?: ""
      val skills = update.skills ?: existing?.skills ?: emptyList()
      val dateOfBirth = if (update.dateOfBirth != null) {
        val dob = update.dateOfBirth
        if (dob.isNullOrBlank()) null else LocalDate.parse(dob)
      } else {
        existing?.dateOfBirth
      }
      val skillsJson = json.encodeToString(skills)

      if (existing == null) {
        StaffDetails.insert {
          it[StaffDetails.userId] = userId
          it[StaffDetails.contactInformation] = contactInformation
          it[StaffDetails.phoneNumber] = phoneNumber
          it[StaffDetails.skills] = skillsJson
          it[StaffDetails.dateOfBirth] = dateOfBirth
        }
      } else {
        StaffDetails.update({ StaffDetails.userId eq userId }) {
          it[StaffDetails.contactInformation] = contactInformation
          it[StaffDetails.phoneNumber] = phoneNumber
          it[StaffDetails.skills] = skillsJson
          it[StaffDetails.dateOfBirth] = dateOfBirth
        }
      }
    }
  }
}

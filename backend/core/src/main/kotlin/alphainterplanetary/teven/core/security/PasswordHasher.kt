package alphainterplanetary.teven.core.security

import org.mindrot.jbcrypt.BCrypt
import org.slf4j.LoggerFactory

object PasswordHasher {
  private val logger = LoggerFactory.getLogger(PasswordHasher::class.java)

  /**
   * The bcrypt cost factor.
   *
   * jBCrypt's default is 10, which is left alone deliberately — changing it
   * would invalidate every existing hash on upgrade without the migration to
   * go with it. Raise it as a separate, considered change.
   */
  private const val DEFAULT_COST = 10

  fun hashPassword(password: String): String {
    return BCrypt.hashpw(password, BCrypt.gensalt(DEFAULT_COST))
  }

  /**
   * Whether [password] is the one [hashed] was produced from.
   *
   * **A stored value that is not a bcrypt hash is a failed login, not a
   * crash.** `BCrypt.checkpw` throws `IllegalArgumentException` on anything its
   * salt parser rejects — a plaintext value, an empty string, a `$2y$` hash,
   * a truncated one — and `AuthServiceImpl` used to call it directly. The
   * exception escaped to `Application.kt`'s catch-all and the caller got a
   * **500 carrying `cause.stackTraceToString()`** instead of a 401, which is
   * both the wrong answer and the stack-trace leak of task 9.9 arriving through
   * a second door.
   *
   * The seed data made this reachable: `TestDataProvider` wrote the literal
   * string `"password"` into `users.password`, so every seeded account
   * (`alice`, `bob`, `charlie`, `diana`) answered HTTP 500 on login. That is
   * fixed at the source in `TestDataProvider`, but corrupting a hash by hand,
   * restoring a dump from another system, or a future migration writing the
   * wrong shape all reach the same place, so the boundary is defended here
   * rather than only at the one call site that was noticed.
   *
   * The exception is logged at WARN, not silently swallowed: a row that cannot
   * be verified is data corruption, and it should be visible in the server log
   * even though it is not the caller's problem.
   *
   * **`RuntimeException`, not `IllegalArgumentException`.** `checkpw` validates
   * its salt by indexing the string without bounds checks, so a short stored
   * value raises `StringIndexOutOfBoundsException` and a `$2y$` hash raises
   * `IllegalArgumentException` — two different types from the same call. Both
   * were found by `PasswordHasherTest`, and the first version of this method
   * caught only the second and still returned HTTP 500 for an empty column.
   * Enumerating a library's failure modes is how that happens; every parse
   * failure here means the same thing, which is that the row is not a hash.
   */
  fun checkPassword(password: String, hashed: String): Boolean {
    return try {
      BCrypt.checkpw(password, hashed)
    } catch (e: RuntimeException) {
      logger.warn("Stored password hash is not a valid bcrypt hash; rejecting the login", e)
      false
    }
  }
}
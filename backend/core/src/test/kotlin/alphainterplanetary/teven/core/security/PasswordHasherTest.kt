package alphainterplanetary.teven.core.security

import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * [PasswordHasher] — task 10.18.
 *
 * The malformed-hash cases are the ones worth having. `BCrypt.checkpw` throws
 * `IllegalArgumentException` on a stored value it cannot parse, and
 * `AuthServiceImpl` used to call it directly, so a corrupted `users.password`
 * row produced an HTTP 500 carrying `cause.stackTraceToString()`. Each test
 * below asserts `false` rather than "does not throw", because "does not throw"
 * would also be satisfied by a method that returned true.
 */
class PasswordHasherTest {

  @Test
  fun `a freshly hashed password verifies`() {
    val hash = PasswordHasher.hashPassword("correct horse battery staple")

    assertTrue(PasswordHasher.checkPassword("correct horse battery staple", hash))
  }

  @Test
  fun `a wrong password is rejected`() {
    val hash = PasswordHasher.hashPassword("correct horse battery staple")

    assertFalse(PasswordHasher.checkPassword("Correct horse battery staple", hash))
    assertFalse(PasswordHasher.checkPassword("", hash))
  }

  @Test
  fun `each hash uses a fresh salt`() {
    // Two accounts with the same password must not share a stored value, or the
    // database reveals which accounts share a password to anyone reading it.
    val first = PasswordHasher.hashPassword("password")
    val second = PasswordHasher.hashPassword("password")

    assertNotEquals(first, second)
    assertTrue(PasswordHasher.checkPassword("password", first))
    assertTrue(PasswordHasher.checkPassword("password", second))
  }

  /**
   * The regression test for task 10.18.
   *
   * `TestDataProvider` wrote the literal string `"password"` into
   * `users.password`. That is what jBCrypt rejects with "Invalid salt version",
   * and it made every seeded account unloggable-in with a 500 rather than a
   * 401. The seed is fixed, but this boundary is what stops the same class of
   * corruption — a restored dump, a bad migration, a hand edit — from being a
   * server error.
   */
  @Test
  fun `a plaintext stored value is a failed login, not an exception`() {
    assertFalse(PasswordHasher.checkPassword("password", "password"))
  }

  @Test
  fun `a stored value that is not a hash at all is rejected`() {
    assertFalse(PasswordHasher.checkPassword("password", ""))
    assertFalse(PasswordHasher.checkPassword("password", "not-a-hash"))
    assertFalse(PasswordHasher.checkPassword("password", "   "))
  }

  /**
   * `$2y$` is what `htpasswd`, PHP's `password_hash` and most tooling emit.
   *
   * jBCrypt parses only `$2a$` and `$2b$`-era prefixes and throws "Invalid
   * salt revision" on the rest, so a hash copied in from another tool is the
   * most likely way a valid-looking value still reaches this method and blows
   * up. Recorded because it is not obvious from the bcrypt documentation, and
   * because it is exactly what happened when this task was verified by hand.
   */
  @Test
  fun `a 2y revision hash is rejected rather than throwing`() {
    val twoY = "\$2y\$10\$lOfGWr/NaECB4qQwY7XTOulJ9ejbZEhVcEgxYMo.qiBomQDH0nN7a"

    assertFalse(PasswordHasher.checkPassword("password", twoY))
  }

  @Test
  fun `a truncated hash is rejected rather than throwing`() {
    val full = PasswordHasher.hashPassword("password")

    assertFalse(PasswordHasher.checkPassword("password", full.take(10)))
  }
}
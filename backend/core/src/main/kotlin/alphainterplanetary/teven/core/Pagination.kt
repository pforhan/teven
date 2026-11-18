package alphainterplanetary.teven.core

object Pagination {
  const val DEFAULT_LIMIT: Int = 25
  const val MAX_LIMIT: Int = 100
  const val MAX_LIMIT_DATE_BOUNDED_EVENTS: Int = 500

  fun effectiveLimit(requested: Int?, max: Int = MAX_LIMIT): Int =
    (requested ?: DEFAULT_LIMIT).coerceIn(1, max)
}

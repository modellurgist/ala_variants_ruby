# Settings for ala_lint_ruby: the application file, the domain, the paradigms and Foundation, by directory.
{
  paths: %w[lib bin],
  layers: [
    { name: :application, paths: [%r{\Alib/thermometer\.rb\z}, %r{\Abin/}] },
    { name: :domain, paths: [%r{\Alib/thermometer/domain_abstractions/}] },
    { name: :paradigms, paths: [%r{\Alib/thermometer/programming_paradigms/}], peer_ok: true },
    { name: :foundation, paths: [%r{\Alib/thermometer/foundation/}], peer_ok: true }
  ],
  min_score: 100
}

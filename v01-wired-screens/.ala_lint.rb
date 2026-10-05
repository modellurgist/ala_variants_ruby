# Settings for ala_lint_ruby. Layers are declared top first; the first is the composition.
{
  layers: [
    { name: :application, paths: [%r{\Aapp/ala/screens/}, %r{\Aapp/controllers/}, %r{\Aapp/views/(?!components/)}, %r{\Aconfig/routes\.rb}, %r{\Alib/tasks/}] },
    { name: :domain, paths: [%r{\Aapp/ala/domain_abstractions/}, %r{\Aapp/views/components/}, %r{\Aapp/helpers/}] },
    { name: :paradigms, paths: [%r{\Aapp/ala/programming_paradigms/}] },
    { name: :foundation, paths: [%r{\Aapp/ala/foundation/}, %r{\Aapp/models/}, %r{\Aapp/jobs/}, %r{\Aapp/channels/}], uses: [/\AApplicationRecord\z/], peer_ok: true }
  ],
  identity_models: %w[Cart],
  exclude: [%r{/views/layouts/}],
  min_score: 80
}

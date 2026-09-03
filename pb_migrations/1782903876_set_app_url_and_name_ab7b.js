migrate((app) => {
  const settings = app.settings()
  settings.meta.appName = "My Healthy Start · Sihat Dari Mula"
  settings.meta.appURL  = "https://app.sihatdarimula.my"
  app.save(settings)
}, (app) => {
  const settings = app.settings()
  settings.meta.appName = "Acme"
  settings.meta.appURL  = "http://localhost:8090"
  app.save(settings)
})
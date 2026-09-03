migrate((app) => {
  const articles = app.findCollectionByNameOrId("articles")
  articles.fields.add(new TextField({ name: "youtube_url", max: 300 }))
  app.save(articles)
}, (app) => {
  const articles = app.findCollectionByNameOrId("articles")
  articles.fields.removeByName("youtube_url")
  app.save(articles)
})
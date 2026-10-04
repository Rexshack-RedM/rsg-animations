const { createApp } = Vue

const post = (endpoint, data = {}) =>
  fetch(`https://${GetParentResourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  }).catch(() => {})

createApp({
  data() {
    return {
      Show: false,
      Animations: [],
      Locale: {},
      searchQuery: '',
      selectedCategory: null,
      Categories: [
        { key: 'Gestures', locale: 'gestures' },
        { key: 'Dances', locale: 'dances' },
        { key: 'Emotes', locale: 'emotes' },
        { key: 'Favorites', locale: 'favorites' },
      ],
    }
  },
  mounted() {
    window.addEventListener('message', this.Message)
    window.addEventListener('keydown', this.onKeypress)
  },
  computed: {
    FilteredAnimations() {
      let filtered = this.Animations
      if (this.selectedCategory === 'Favorites') {
        filtered = filtered.filter(a => a.Favorite)
      } else if (this.selectedCategory) {
        filtered = filtered.filter(a => a.Category === this.selectedCategory)
      }
      const query = this.searchQuery.trim().toLowerCase()
      if (query) {
        filtered = filtered.filter(a => (a.DisplayLabel || a.Label).toLowerCase().includes(query))
      }
      return filtered
    },
  },
  methods: {
    Message(event) {
      if (event.data.type === 'Open') {
        this.Animations = event.data.Animations || []
        this.Locale = event.data.Locale || {}
        this.Show = true
        this.$nextTick(() => this.$refs.search && this.$refs.search.focus())
      }
    },
    TypeIcon(type) {
      return type === 'Emote' ? '\u263A' : type === 'Scenario' ? '\u2691' : '\u2726'
    },
    CategoryLabel(category) {
      const cat = this.Categories.find(c => c.key === category)
      return cat ? this.Locale[cat.locale] : category
    },
    StartAnim(Animation) {
      post('Play', { label: Animation.Label })
    },
    StopAnim() {
      post('StopAnim')
    },
    onKeypress(event) {
      if (this.Show && event.key === 'Escape') this.Close()
    },
    FilterCategory(category) {
      this.selectedCategory = this.selectedCategory === category ? null : category
    },
    Favorite(Animation) {
      Animation.Favorite = !Animation.Favorite
      post('Favorite', { label: Animation.Label, favorite: Animation.Favorite })
    },
    Close() {
      this.Show = false
      this.searchQuery = ''
      post('Close')
    },
  },
}).mount('#app')

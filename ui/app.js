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
      upperBody: false,
      Slots: [],
      Recent: [],
      Walkstyles: [],
      CurrentWalk: 'normal',
      assigning: null,
      NowPlaying: { Name: '', Hint: '' },
      Invite: { Text: '', Hint: '' },
      selectedCategory: null,
      Categories: [
        { key: 'Gestures', locale: 'gestures' },
        { key: 'Dances', locale: 'dances' },
        { key: 'Emotes', locale: 'emotes' },
        { key: 'Favorites', locale: 'favorites' },
        { key: 'Recent', locale: 'recent' },
        { key: 'Together', locale: 'together' },
        { key: 'Walk', locale: 'walk' },
      ],
    }
  },
  mounted() {
    window.addEventListener('message', this.Message)
    window.addEventListener('keydown', this.onKeypress)
    this.selectedCategory = this.Load('category') || null
    this.upperBody = this.Load('upper') === '1'
  },
  computed: {
    VisibleCategories() {
      return this.Categories.filter(c => {
        if (c.key === 'Walk') return this.Walkstyles.length > 0
        if (c.key === 'Together') return this.Animations.some(a => a.Shared)
        return true
      })
    },
    FilteredWalkstyles() {
      const query = this.searchQuery.trim().toLowerCase()
      return this.Walkstyles.filter(w => w.label.toLowerCase().includes(query))
    },
    FilteredAnimations() {
      let filtered = this.Animations
      if (this.selectedCategory === 'Favorites') {
        filtered = filtered.filter(a => a.Favorite)
      } else if (this.selectedCategory === 'Recent') {
        filtered = this.Recent.map(label => filtered.find(a => a.Label === label)).filter(Boolean)
      } else if (this.selectedCategory === 'Together') {
        filtered = filtered.filter(a => a.Shared)
      } else if (this.selectedCategory) {
        filtered = filtered.filter(a => a.Category === this.selectedCategory)
      }
      const query = this.searchQuery.trim().toLowerCase()
      if (query) {
        filtered = filtered.filter(a =>
          a.DisplayLabel.toLowerCase().includes(query) || a.Label.toLowerCase().includes(query))
      }
      return filtered
    },
  },
  watch: {
    searchQuery() { this.ScrollTop() },
    selectedCategory(value) {
      this.Save('category', value || '')
      this.ScrollTop()
    },
    upperBody(value) { this.Save('upper', value ? '1' : '') },
  },
  methods: {
    Message(event) {
      if (event.data.type === 'Open') {
        // an empty Lua table arrives as {} rather than []
        const favorites = new Set(Array.isArray(event.data.Favorites) ? event.data.Favorites : [])
        this.Animations = (event.data.Animations || []).map(a => ({ ...a, Favorite: favorites.has(a.Label) }))
        this.Locale = event.data.Locale || {}
        // empty Lua tables arrive as {} rather than []
        this.Recent = Array.isArray(event.data.Recent) ? event.data.Recent : []
        this.Walkstyles = Array.isArray(event.data.Walkstyles) ? event.data.Walkstyles : []
        this.Slots = event.data.Slots || []
        this.CurrentWalk = event.data.CurrentWalk
        // a remembered tab may be unavailable now
        if (this.selectedCategory && !this.VisibleCategories.some(c => c.key === this.selectedCategory)) {
          this.selectedCategory = null
        }
        this.Show = true
        this.$nextTick(() => this.$refs.search && this.$refs.search.focus())
      } else if (event.data.type === 'Slots') {
        this.Slots = event.data.Slots
      } else if (event.data.type === 'Recent') {
        // don't reorder the Recent tab under the cursor
        if (!this.Show || this.selectedCategory !== 'Recent') this.Recent = Array.isArray(event.data.Recent) ? event.data.Recent : []
      } else if (event.data.type === 'Walk') {
        this.CurrentWalk = event.data.Current
      } else if (event.data.type === 'NowPlaying') {
        this.NowPlaying = { Name: event.data.Name, Hint: event.data.Hint }
      } else if (event.data.type === 'Invite') {
        this.Invite = { Text: event.data.Text, Hint: event.data.Hint }
      } else if (event.data.type === 'Close') {
        this.Reset()
      } else if (event.data.type === 'SetFavorite') {
        const anim = this.Animations.find(a => a.Label === event.data.label)
        if (anim) anim.Favorite = event.data.favorite
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
      if (this.selectedCategory === 'Together') return this.InvitePlayer(Animation)
      post('Play', { label: Animation.Label, upper: this.upperBody })
    },
    InvitePlayer(Animation) {
      this.Reset()
      post('Invite', { label: Animation.Label })
    },
    SetWalk(walk) {
      post('Walk', { key: walk.key })
    },
    SlotName(label) {
      const anim = this.Animations.find(a => a.Label === label)
      return anim ? anim.DisplayLabel : ''
    },
    Assign(Animation) {
      this.assigning = this.assigning === Animation.Label ? null : Animation.Label
    },
    UseSlot(index) {
      if (this.assigning) {
        post('SetSlot', { slot: index + 1, label: this.assigning })
        this.assigning = null
      } else if (this.Slots[index]) {
        post('Play', { label: this.Slots[index], upper: this.upperBody })
      }
    },
    ClearSlot(index) {
      post('SetSlot', { slot: index + 1 })
    },
    StopAnim() {
      post('StopAnim')
    },
    onKeypress(event) {
      if (!this.Show) return
      if (event.key === 'Escape') {
        // first Escape clears the search, the next one closes the menu
        if (this.assigning) this.assigning = null
        else if (this.searchQuery) this.searchQuery = ''
        else this.Close()
      } else if (event.key === 'Enter' && !event.repeat && this.searchQuery.trim()) {
        event.preventDefault() // a focused button must not also be clicked
        if (this.selectedCategory === 'Walk') {
          if (this.FilteredWalkstyles.length) this.SetWalk(this.FilteredWalkstyles[0])
        } else if (this.FilteredAnimations.length) {
          this.StartAnim(this.FilteredAnimations[0])
        }
      }
    },
    FilterCategory(category) {
      this.selectedCategory = this.selectedCategory === category ? null : category
    },
    Favorite(Animation) {
      Animation.Favorite = !Animation.Favorite
      post('Favorite', { label: Animation.Label, favorite: Animation.Favorite })
    },
    ScrollTop() {
      if (this.$refs.list) this.$refs.list.scrollTop = 0
    },
    // browser storage is only a per-player convenience and may be unavailable
    Load(key) {
      try { return localStorage.getItem(`rsg-animations:${key}`) } catch (e) { return null }
    },
    Save(key, value) {
      try { localStorage.setItem(`rsg-animations:${key}`, value) } catch (e) { /* ignore */ }
    },
    Reset() {
      this.Show = false
      this.searchQuery = ''
      this.assigning = null
    },
    Close() {
      this.Reset()
      post('Close')
    },
  },
}).mount('#app')

<script setup>
import {ref} from 'vue'

defineProps({
  msg: String,
})

const count = ref(0)
</script>

<template>
  <h2>{{ msg }}</h2>

  <div class="card">
    <button type="button" @click="count++">Count is {{ count }}</button>
    <p style="font-size:3em">
      🤓
    </p>
  </div>

  <p>
    Check out
    <a href="https://github.com/hmcts/version-reporter-services/blob/master/README.md" target="_blank"
    >the README</a>, for more detail
  </p>
  <p class="read-the-docs">This is currently a work-in-progress and would be updated often</p>
</template>

<style scoped>
.read-the-docs {
  color: #888;
}
</style>

<script setup>
import HelloWorld from './components/Dashboard.vue'
</script>

<template>
  <div class="vrs_header">
    <h1>Version Reporter Dashboard</h1>
  </div>
  <HelloWorld msg="[WIP]"/>
</template>

<style scoped>
.vrs_header {

}

.logo {
  height: 6em;
  padding: 1.5em;
  will-change: filter;
  transition: filter 300ms;
}

.logo:hover {
  filter: drop-shadow(0 0 2em #646cffaa);
}

.logo.vue:hover {
  filter: drop-shadow(0 0 2em #42b883aa);
}
</style>

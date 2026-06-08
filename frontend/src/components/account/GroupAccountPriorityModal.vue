<template>
  <BaseDialog :show="show" :title="t('admin.accounts.groupPriority.title')" width="wide" @close="handleClose">
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="min-w-0">
          <div class="truncate text-sm font-medium text-gray-900 dark:text-white">
            {{ groupName }}
          </div>
          <div class="text-xs text-gray-500 dark:text-gray-400">
            {{ t('admin.accounts.groupPriority.currentPageHint', { count: rows.length }) }}
          </div>
        </div>
        <button type="button" class="btn btn-secondary px-3 py-2 text-sm" @click="normalizePriorities">
          {{ t('admin.accounts.groupPriority.normalize') }}
        </button>
      </div>

      <div class="overflow-hidden rounded-lg border border-gray-200 dark:border-dark-600">
        <div class="max-h-[60vh] overflow-auto">
          <table class="min-w-full divide-y divide-gray-200 text-sm dark:divide-dark-600">
            <thead class="sticky top-0 z-10 bg-gray-50 dark:bg-dark-800">
              <tr>
                <th class="px-3 py-2 text-left font-medium text-gray-500 dark:text-gray-400">
                  {{ t('admin.accounts.name') }}
                </th>
                <th class="w-28 px-3 py-2 text-left font-medium text-gray-500 dark:text-gray-400">
                  {{ t('admin.accounts.groupPriority.priority') }}
                </th>
                <th class="w-36 px-3 py-2 text-left font-medium text-gray-500 dark:text-gray-400">
                  {{ t('common.actions') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 bg-white dark:divide-dark-700 dark:bg-dark-900">
              <tr v-for="(row, index) in rows" :key="row.account.id">
                <td class="px-3 py-2">
                  <div class="min-w-0">
                    <div class="truncate font-medium text-gray-900 dark:text-white">
                      {{ row.account.name }}
                    </div>
                    <div class="text-xs text-gray-500 dark:text-gray-400">
                      #{{ row.account.id }} · {{ row.account.platform }} / {{ row.account.type }}
                    </div>
                  </div>
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model.number="row.priority"
                    type="number"
                    min="1"
                    class="input h-9 w-24"
                    @input="row.priority = sanitizePriority(row.priority)"
                  />
                </td>
                <td class="px-3 py-2">
                  <div class="flex items-center gap-1">
                    <button
                      type="button"
                      class="rounded p-1.5 text-gray-500 hover:bg-gray-100 hover:text-gray-900 disabled:opacity-40 dark:hover:bg-dark-700 dark:hover:text-white"
                      :title="t('admin.accounts.groupPriority.toTop')"
                      :disabled="index === 0"
                      @click="moveToTop(index)"
                    >
                      <Icon name="arrowUp" size="sm" />
                    </button>
                    <button
                      type="button"
                      class="rounded p-1.5 text-gray-500 hover:bg-gray-100 hover:text-gray-900 disabled:opacity-40 dark:hover:bg-dark-700 dark:hover:text-white"
                      :title="t('admin.accounts.groupPriority.moveUp')"
                      :disabled="index === 0"
                      @click="moveBy(index, -1)"
                    >
                      <Icon name="chevronUp" size="sm" />
                    </button>
                    <button
                      type="button"
                      class="rounded p-1.5 text-gray-500 hover:bg-gray-100 hover:text-gray-900 disabled:opacity-40 dark:hover:bg-dark-700 dark:hover:text-white"
                      :title="t('admin.accounts.groupPriority.moveDown')"
                      :disabled="index === rows.length - 1"
                      @click="moveBy(index, 1)"
                    >
                      <Icon name="chevronDown" size="sm" />
                    </button>
                  </div>
                </td>
              </tr>
              <tr v-if="rows.length === 0">
                <td colspan="3" class="px-3 py-8 text-center text-sm text-gray-500 dark:text-gray-400">
                  {{ t('admin.accounts.groupPriority.empty') }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex justify-end gap-3">
        <button type="button" class="btn btn-secondary" @click="handleClose">
          {{ t('common.cancel') }}
        </button>
        <button type="button" class="btn btn-primary" :disabled="rows.length === 0" @click="handleSave">
          {{ t('common.save') }}
        </button>
      </div>
    </template>
  </BaseDialog>
</template>

<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import BaseDialog from '@/components/common/BaseDialog.vue'
import Icon from '@/components/icons/Icon.vue'
import type { Account, AdminGroup } from '@/types'

type PriorityRow = {
  account: Account
  priority: number
}

const props = defineProps<{
  show: boolean
  group: AdminGroup | null
  accounts: Account[]
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'save', items: Array<{ account_id: number; priority: number }>): void
}>()

const { t } = useI18n()
const rows = ref<PriorityRow[]>([])
const groupName = computed(() => props.group?.name || t('admin.accounts.groupPriority.groupFallback'))

function priorityFor(account: Account): number {
  const groupID = props.group?.id
  const item = account.account_groups?.find((entry) => entry.group_id === groupID)
  return sanitizePriority(item?.priority ?? account.priority ?? 50)
}

function sanitizePriority(value: unknown): number {
  const n = Number(value)
  if (!Number.isFinite(n) || n < 1) return 1
  return Math.floor(n)
}

function rebuildRows() {
  const groupID = props.group?.id
  if (!props.show || !groupID) {
    rows.value = []
    return
  }
  rows.value = props.accounts
    .filter((account) =>
      account.group_ids?.includes(groupID) ||
      account.groups?.some((group) => group.id === groupID) ||
      account.account_groups?.some((entry) => entry.group_id === groupID)
    )
    .map((account) => ({
      account,
      priority: priorityFor(account)
    }))
    .sort((a, b) => a.priority - b.priority || a.account.priority - b.account.priority || a.account.id - b.account.id)
}

function normalizePriorities() {
  rows.value.forEach((row, index) => {
    row.priority = index + 1
  })
}

function moveToTop(index: number) {
  if (index <= 0) return
  const [item] = rows.value.splice(index, 1)
  rows.value.unshift(item)
  normalizePriorities()
}

function moveBy(index: number, offset: number) {
  const nextIndex = index + offset
  if (nextIndex < 0 || nextIndex >= rows.value.length) return
  const [item] = rows.value.splice(index, 1)
  rows.value.splice(nextIndex, 0, item)
  normalizePriorities()
}

function handleClose() {
  emit('close')
}

function handleSave() {
  emit('save', rows.value.map((row) => ({
    account_id: row.account.id,
    priority: sanitizePriority(row.priority)
  })))
}

watch(() => [props.show, props.group?.id, props.accounts] as const, rebuildRows, { immediate: true, deep: true })
</script>

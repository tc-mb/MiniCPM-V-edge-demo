// ArkUI LazyForEach data source for the chat list. Stands in for both the
// `RecyclerView.Adapter` (ChatAdapter.kt) and `messages: MutableList<ChatMessage>`
// in the Android demo.
//
// LazyForEach's IDataSource contract is intentionally minimal — only the
// integer change events are supported, so we keep the same incremental
// notify pattern the Android adapter uses (DiffUtil there, explicit
// notifyChange/notifyAdd here). All updates are O(1) at the source level;
// ArkUI takes care of reusing item ViewHolders.

import { ChatMessage } from '../data/ChatMessage';

export class ChatMessageList implements IDataSource {
  private items: ChatMessage[] = [];
  private listeners: DataChangeListener[] = [];

  // ----- IDataSource API -----

  totalCount(): number { return this.items.length; }

  getData(index: number): ChatMessage { return this.items[index]; }

  registerDataChangeListener(l: DataChangeListener): void {
    if (this.listeners.indexOf(l) < 0) this.listeners.push(l);
  }
  unregisterDataChangeListener(l: DataChangeListener): void {
    const i = this.listeners.indexOf(l);
    if (i >= 0) this.listeners.splice(i, 1);
  }

  // ----- mutation helpers -----

  push(message: ChatMessage): number {
    const idx = this.items.length;
    this.items.push(message);
    for (const l of this.listeners) l.onDataAdd(idx);
    return idx;
  }

  setAll(messages: ChatMessage[]): void {
    this.items = messages;
    for (const l of this.listeners) l.onDataReloaded();
  }

  clear(): void {
    this.items = [];
    for (const l of this.listeners) l.onDataReloaded();
  }

  notifyChange(index: number): void {
    if (index < 0 || index >= this.items.length) return;
    for (const l of this.listeners) l.onDataChange(index);
  }

  removeAt(index: number): void {
    if (index < 0 || index >= this.items.length) return;
    this.items.splice(index, 1);
    for (const l of this.listeners) l.onDataDelete(index);
  }

  indexOfId(id: number): number {
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].id === id) return i;
    }
    return -1;
  }

  // For uniqueId in LazyForEach. Welcome card always has id 0; user/AI
  // messages get monotonically increasing ids.
  static keyForMessage(m: ChatMessage): string { return `${m.kind}-${m.id}`; }
}

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { normaliseSku, stockFill, stockStatus } from './inventory.js';

test('stockStatus flags out-of-stock, reorder and healthy items', () => {
  assert.equal(stockStatus({ quantity: 0, reorder_level: 5 }).tone, 'danger');
  assert.equal(stockStatus({ quantity: 5, reorder_level: 5 }).tone, 'warn');
  assert.equal(stockStatus({ quantity: 6, reorder_level: 5 }).tone, 'ok');
});

test('stockFill is capped at 100 percent', () => {
  assert.equal(stockFill({ quantity: 100, reorder_level: 5 }), 100);
  assert.equal(stockFill({ quantity: 0, reorder_level: 0 }), 0);
});

test('normaliseSku upper-cases and dashes whitespace', () => {
  assert.equal(normaliseSku('  kb 1042 '), 'KB-1042');
});

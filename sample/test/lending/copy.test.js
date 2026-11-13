import { test } from 'node:test';
import assert from 'node:assert/strict';
import { decide } from '../../src/lending/copy.js';

// esdm:domain=library/bounded-context=lending/aggregate=copy/feature=borrowing-a-copy scenario=available-copy-can-be-borrowed
test('available-copy-can-be-borrowed', () => {
  const history = [
    { type: 'stocked', data: { 'copy-id': '11111111-1111-1111-1111-111111111111', isbn: '978-0201616224' } },
  ];

  const events = decide(
    {
      type: 'borrow',
      data: { 'copy-id': '11111111-1111-1111-1111-111111111111', borrower: 'card-4711', 'due-on': '2026-09-14' },
    },
    history,
  );

  assert.deepEqual(events, [
    {
      type: 'borrowed',
      data: {
        'copy-id': '11111111-1111-1111-1111-111111111111',
        isbn: '978-0201616224',
        borrower: 'card-4711',
        'due-on': '2026-09-14',
      },
    },
  ]);
});

// esdm:domain=library/bounded-context=lending/aggregate=copy/feature=borrowing-a-copy scenario=copy-already-on-loan-is-refused
test('copy-already-on-loan-is-refused', () => {
  const history = [
    { type: 'stocked', data: { 'copy-id': '11111111-1111-1111-1111-111111111111', isbn: '978-0201616224' } },
    {
      type: 'borrowed',
      data: {
        'copy-id': '11111111-1111-1111-1111-111111111111',
        isbn: '978-0201616224',
        borrower: 'card-4711',
        'due-on': '2026-09-14',
      },
    },
  ];

  assert.throws(
    () =>
      decide(
        {
          type: 'borrow',
          data: { 'copy-id': '11111111-1111-1111-1111-111111111111', borrower: 'card-0815', 'due-on': '2026-09-21' },
        },
        history,
      ),
    { invariant: 'only-available-copies-can-be-borrowed' },
  );
});

// esdm:domain=library/bounded-context=lending/aggregate=copy/feature=borrowing-a-copy scenario=returned-copy-becomes-borrowable-again
test('returned-copy-becomes-borrowable-again', () => {
  const history = [
    { type: 'stocked', data: { 'copy-id': '11111111-1111-1111-1111-111111111111', isbn: '978-0201616224' } },
    {
      type: 'borrowed',
      data: {
        'copy-id': '11111111-1111-1111-1111-111111111111',
        isbn: '978-0201616224',
        borrower: 'card-4711',
        'due-on': '2026-09-14',
      },
    },
    {
      type: 'returned',
      data: { 'copy-id': '11111111-1111-1111-1111-111111111111', isbn: '978-0201616224', 'returned-on': '2026-09-10' },
    },
  ];

  const events = decide(
    {
      type: 'borrow',
      data: { 'copy-id': '11111111-1111-1111-1111-111111111111', borrower: 'card-0815', 'due-on': '2026-09-21' },
    },
    history,
  );

  assert.deepEqual(events, [
    {
      type: 'borrowed',
      data: {
        'copy-id': '11111111-1111-1111-1111-111111111111',
        isbn: '978-0201616224',
        borrower: 'card-0815',
        'due-on': '2026-09-21',
      },
    },
  ]);
});

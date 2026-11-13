// Returning a copy. Written separately from copy.js when kiosk returns were
// added, so it folds the copy's events itself rather than going through decide.

import { placeHold } from '../reservations/hold.js';

const GRACE_DAYS = 3;
const CENTS_PER_LATE_DAY = 50;

function daysBetween(from, to) {
  return Math.round((Date.parse(to) - Date.parse(from)) / 86_400_000);
}

export function returnCopy(history, { returnedOn, condition = 'good', nextInLine }) {
  const borrowed = history.findLast((event) => event.type === 'borrowed');
  const returned = history.findLast((event) => event.type === 'returned');
  if (!borrowed || (returned && history.lastIndexOf(returned) > history.lastIndexOf(borrowed))) {
    throw new Error('copy is not on loan');
  }
  const { 'copy-id': copyId, isbn, borrower, 'due-on': dueOn } = borrowed.data;

  const events = [{ type: 'returned', data: { 'copy-id': copyId, isbn, 'returned-on': returnedOn } }];

  const lateDays = daysBetween(dueOn, returnedOn);
  if (lateDays > GRACE_DAYS) {
    events.push({
      type: 'fee-incurred',
      data: {
        'copy-id': copyId,
        isbn,
        borrower,
        'due-on': dueOn,
        'returned-on': returnedOn,
        'amount-in-cents': lateDays * CENTS_PER_LATE_DAY,
      },
    });
  }

  if (condition === 'damaged') {
    events.push({ type: 'damage-reported', data: { 'copy-id': copyId, borrower, 'reported-on': returnedOn } });
  }

  // Whoever reserved this title first gets the copy on the hold shelf.
  const holdEvents = nextInLine ? placeHold({ 'copy-id': copyId, isbn, borrower: nextInLine }, returnedOn) : [];

  return { events, holdEvents };
}

// The copy aggregate: decides a command against the events of one copy.
// Events and command data use the model's field names.

export class Rejection extends Error {
  constructor(invariant) {
    super(`rejected by ${invariant}`);
    this.invariant = invariant;
  }
}

function evolve(state, event) {
  switch (event.type) {
    case 'stocked':
      return { copyId: event.data['copy-id'], isbn: event.data.isbn, status: 'available' };
    case 'borrowed':
      return { ...state, status: 'on-loan', borrower: event.data.borrower, dueOn: event.data['due-on'] };
    case 'returned':
      return { copyId: state.copyId, isbn: state.isbn, status: 'available' };
    default:
      return state;
  }
}

export function decide(command, history) {
  const copy = history.reduce(evolve, undefined);
  switch (command.type) {
    case 'borrow':
      if (copy.status === 'on-loan') throw new Rejection('only-available-copies-can-be-borrowed');
      return [
        {
          type: 'borrowed',
          data: {
            'copy-id': copy.copyId,
            isbn: copy.isbn,
            borrower: command.data.borrower,
            'due-on': command.data['due-on'],
          },
        },
      ];
    default:
      throw new Error(`unknown command ${command.type}`);
  }
}

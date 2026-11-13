// The hold aggregate's place command, as lending's returning code calls it.

export function placeHold({ 'copy-id': copyId, isbn, borrower }, placedOn) {
  return [{ type: 'placed', data: { 'copy-id': copyId, isbn, borrower, 'placed-on': placedOn } }];
}

String? gaslessQuoteBlockingMessage(Map<String, dynamic> quote) {
  if (quote['liquidityAvailable'] == false) {
    return 'This amount is too low for a gasless route. Increase the amount or turn off Gasless to use a regular swap.';
  }
  final issues = quote['issues'];
  if (issues is Map && issues['simulationIncomplete'] == true) {
    return 'This gasless swap could not be validated safely. Try a larger amount or turn off Gasless.';
  }
  return null;
}

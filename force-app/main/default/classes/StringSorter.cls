/**
 * @description Utility class providing methods to sort lists of strings alphabetically.
 */
public with sharing class StringSorter {

    /**
     * @description Returns a new list containing the provided strings sorted in ascending alphabetical order.
     * @param inputStrings The list of strings to sort.
     * @return A new List<String> sorted alphabetically (ascending).
     */
    public static List<String> sortAlphabetically(List<String> inputStrings) {
        List<String> sortedStrings = new List<String>(inputStrings);
        sortedStrings.sort();
        return sortedStrings;
    }
}

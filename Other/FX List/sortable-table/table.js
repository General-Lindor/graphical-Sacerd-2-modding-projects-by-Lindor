// Sorts a tables rows by a specific column without changing the order of rows with the same content in the columns cell
// A slow but stable sorting Algorithm of O(n^2)
// "Stable" is a description of sorting algorithms in informatics and means that it does not change the order of rows with the same content
function sortTableByColumn(tableID, columnIndex) {
    var table, rows, i, runs, x, y, issorted;
    table = document.getElementById(tableID);
    rows = table.rows;
    runs = rows.length - 1;
    // the issorted var is not strictly necessary; it's there to speed the algorithm up, e.g. in case of an already sorted table
    issorted = false;
    // loop through the rows
    while ((issorted == false) && (runs > 0)) {
        issorted = true;
        // Ensure that the largest element is at the end of the run
        for (i = 1; i < runs; i++) {
            x = rows[i].getElementsByTagName("td")[columnIndex];
            y = rows[i + 1].getElementsByTagName("td")[columnIndex];
            if (x.innerHTML.toLowerCase() > y.innerHTML.toLowerCase()) {
                rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
                issorted = false;
            }
        }
        runs = runs - 1;
    }
}

// Sorts a tables rows first by the last column, then the second-to-last and so on all the way up to the first column,
// ensuring that the table is always ordered by the first column.
function sortTable(tableID) {
    var length, i;
    length = document.getElementById(tableID).rows[0].cells.length - 1;
    for (i = length; i >= 0; i = i - 1) {
        sortTableByColumn(tableID, i);
    }
}

/*
// Filter a table by 
function filter(tableID, filterID, columnIndex) {
    // Declare variables
    var table, tableRows, tableRows, tableCell, tableCellContent, filterInput, filterContent, i;
    table = document.getElementById(tableID);
    tableRows = table.getElementsByTagName("tr");
    filterInput = document.getElementById(filterID);
    filterContent = filterInput.value.toLowerCase();

    // Loop through all table rows
    for (i = 0; i < tableRows.length; i++) {
        // The table cell at the column index of the row
        tableCell = tableRows[i].getElementsByTagName("td")[columnIndex];
        // Does the cell even exits or is it a none value?
        if (tableCell) {
            tableCellContent = tableCell.textContent || tableCell.innerText;
            // does tableCellContent contain filterContent somewhere?
            if (tableCellContent.toLowerCase().indexOf(filterContent) > -1) {
                tableRows[i].style.display = "";
            } else {
                tableRows[i].style.display = "none";
            }
        }
    }
}
*/

// Filter a table by 
function filter(tableID, filterID, columnIndex) {
    // Declare variables
    var table, tableRows, tableRows, tableCell, tableCellContent, filterInput, filterContent, i, j;
    table = document.getElementById(tableID);
    tableRows = table.getElementsByTagName("tr");
    filterInput = document.getElementById(filterID);
    filterContent = filterInput.value.toLowerCase();

    // Loop through all table rows
    for (i = 0; i < tableRows.length; i++) {
        // The table cell at the column index of the row
        tableCell = tableRows[i].getElementsByTagName("td")[columnIndex];
        // Does the cell even exits or is it a none value?
        if (tableCell) {
            tableCellContent = tableCell.textContent || tableCell.innerText;
            // does tableCellContent contain filterContent somewhere?
            if (tableCellContent.toLowerCase().indexOf(filterContent) > -1) {
                tableCell.setAttribute("needsToBeHidden", "0");
            } else {
                tableCell.setAttribute("needsToBeHidden", "1");
            }
        }
    }
    
    for (i = 0; i < tableRows.length; i++) {
        tableRows[i].style.display = "";
        for (j = 0; j < tableRows[0].cells.length; j++) {
            tableCell = tableRows[i].getElementsByTagName("td")[j];
            if (tableCell) {
                if (tableCell.getAttribute("needsToBeHidden") == "1") {
                    tableRows[i].style.display = "none";
                    break;
                }
            }
        }
    }
}
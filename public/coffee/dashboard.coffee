classForPriority = (priority) ->
        switch priority
                when "10 - high" then "danger"
                when "20 - medium" then "warning"
                when "40 - low" then "info"
                else ""

issueRow = (url, description, date, owner, priority) ->
        row = $("<tr></tr>").addClass(classForPriority(priority))
        link = $("<a></a>").attr("href", url).append(description)
        row.append($("<td></td>").append(link))
        row.append($("<td></td>").append(date))
        row.append($("<td></td>").append(owner))
        row.append($("<td></td>").append(priority))

updateCounts = (recentlyOpened, recentlyClosed) ->
        $("#recentlyOpened").html(recentlyOpened)
        $("#recentlyClosed").html(recentlyClosed)

updateOpenIssues = (issues) ->
        body = $("<tbody></tbody>")
        for i in issues
                body.append(issueRow(i.url, i.description, i.when_opened, i.owner, i.priority))
        
        $("#openIssuesTable").empty()
        $("#openIssuesTable").append("<thead><tr>
                <th>Issue Description</th>
                <th>Opened</th>
                <th>Owner</th>
                <th>Priority</th>
                </tr></thead>")
        $("#openIssuesTable").append(body)
        $("#openIssuesTable").dataTable(paging: false, orderClasses: false, dom: "ilfrtp", order: [3, "asc"])

updateRecentlyClosedIssues = (issues) ->
        body = $("<tbody></tbody>")
        for i in issues
                body.append($("<tr></tr>").append($("<td></td>").append(i.description)))

        selector = "#recentlyClosedTable"
        $(selector).empty()
        $(selector).append("<thead><tr>
                <th>Issue Description</th>
                </tr></thead>")
        $(selector).append(body)
        $(selector).dataTable(paging: false, orderClasses: false, dom: "ilfrtp")

$.ajax({
        url: "/issues",
        success: (_, _2, result) ->
                updateOpenIssues(result.responseJSON.issues)
                updateCounts(result.responseJSON.recentlyOpened, result.responseJSON.recentlyClosed)
        })
$.ajax({
        url: "/recentlyClosed",
        success: (_, _2, result) -> updateRecentlyClosedIssues(result.responseJSON.issues)})

<?php
// Database account info
$user = 'root';
$password = '';
$dbname = 'iTunesConnect';

// $langs array converts country codes to full names
require('langs.php');

// arrays for filtering
$valid_regions = array();
if(is_array($_POST['chk_regions'])) $valid_regions = $_POST['chk_regions'];
$valid_countries = array();
foreach($valid_regions as $vr) {
	if(is_array($regions[$vr])) {
		foreach($regions[$vr] as $cname)
			$valid_countries[] = $cname;
	}
}

$db = new mysqli('localhost', $user, $password, $dbname);
if( mysqli_connect_errno() )
{
	printf("Database connect failed: %s\n", mysqli_connect_error());
	exit();
}

$datesSelected = false;
$appsSelected = false;

// Get all available report dates and sales/upgrades for each day
$allDates = array();
$dateSales = array();
$dateUpgrades = array();
$numDates = 0;
$q = 'SELECT UNIX_TIMESTAMP(BeginDate), ProductTypeIdentifier, SUM(Units) FROM dailySalesSummary GROUP BY BeginDate, ProductTypeIdentifier ORDER BY BeginDate DESC';
if( $result = $db->query($q) )
{
	while( $row = $result->fetch_array() )
	{
		switch( intval($row[1]) )
		{
			case 1: $dateSales[$row[0]] = $row[2];	break;
			case 7: $dateUpgrades[$row[0]] = $row[2];	break;
			default:
				echo "Unrecognized ProductTypeIdentifier\n";
				continue 2;
		}
		$allDates[$row[0]] = 0;
	}
	$allDates = array_keys($allDates);
	$numDates = count($allDates);
	$result->close();
}

// Transpose the regions table
foreach($regions as $k => $v)
	foreach($v as $cc)
		$ccToRegion[$cc] = $k;

// Get total sales and upgrades for each region
$q = 'SELECT CountryCode, ProductTypeIdentifier, SUM(Units) FROM dailySalesSummary GROUP BY CountryCode, ProductTypeIdentifier';
if( $result = $db->query($q) )
{
	while( $row = $result->fetch_array() )
	{
		switch( intval($row[1]) )
		{
			case 1: $regionSales[$ccToRegion[$row[0]]] = $row[2];	break;
			case 7: $regionUpgrades[$ccToRegion[$row[0]]] = $row[2];	break;
			default:
				echo "Unrecognized ProductTypeIdentifier\n";
				continue 2;
		}
	}
	$result->close();
}

// Get total sales and updates for each app
$numApps = 0;
$appSales = array();
$appUpdates = array();
$q = 'SELECT VendorIdentifier, TitleEpisodeSeason, numSales, numUpdates, avgDailySales, avgDailyUpdates FROM applications';
if( $result = $db->query($q) )
{
	while( $row = $result->fetch_array() )
	{
		$appSales[$row[1]] = $row[2];
		$appUpdates[$row[1]] = $row[3];
		$avgDailySales[$row[1]] = $row[4];
		$avgDailyUpdates[$row[1]] = $row[5];
		$appNames[] = $row[1];
	}
	$result->close();

	sort($appNames);
	$numApps = count($appNames);
	$appTotalSales = array_sum($appSales);
	$appTotalUpdates = array_sum($appUpdates);
}

// Create a WHERE clause for the set of dates to retrieve
$where = array();
// Use any dates that were selected, otherwise default to the last 7 days
if( is_array($_POST['chk_dates']) )
{
	$where_date = $_POST['chk_dates'];
	$datesSelected = true;
}
else
{
	$where_date = array_slice($allDates, 0, 7);
	foreach( $where_date as &$v )
		$v = date('Y-m-d',$v);
}
foreach($where_date as &$v)
	$v = "BeginDate='$v'";
$where[] = '('.join(' OR ', $where_date).')';

// Create a WHERE clause for the App Names to retrieve
if( is_array($_POST['chk_apps']) )
{
	$appsSelected = true;
	$where_name = $_POST['chk_apps'];
	foreach($where_name as &$v)
		$v = "TitleEpisodeSeason='$v'";
	$where[] = '('.join(' OR ', $where_name).')';
}

$where = join(' AND ', $where);
if( strlen($where) )
	$where = ' WHERE '.$where;

// Get the set of report dates
$dates = array();
$numReportDates = 0;
$q = 'SELECT UNIX_TIMESTAMP(BeginDate) FROM dailySalesSummary'.$where.' GROUP BY BeginDate ORDER BY BeginDate DESC';
if( $result = $db->query($q) )
{
	$numReportDates = $result->num_rows;
	while( $row = $result->fetch_array() )
		$dates[] = $row[0];
	$result->close();
}

// Fetch app info
$reportAppNames = array();
$reportNumApps = 0;
$sales = array();
$totalSales = array();
$totalUpgrades = array();
$upgrades = array();

$q = 'SELECT * FROM dailySalesSummary'.$where;
if( $result = $db->query($q, MYSQLI_USE_RESULT) )
{
	$apps = array();
	while( $row = $result->fetch_assoc() )
	{
		$date = $row['BeginDate'];
		$name = $row['TitleEpisodeSeason'];
		$units = intval($row['Units']);
		switch( intval($row['ProductTypeIdentifier']) )
		{
			case 1:
				$totalSales[$date][$name] += $units;
				$totalAppSales[$name] += $units;
				$numCountrySales[$name][$row['CountryCode']] += $units;
				$sales[$date][$name][$row['CountryCode']] += $units;
				break;
			case 7:
				$totalUpgrades[$date][$name] += $units;
				$totalAppUpgrades[$name] += $units;
				$upgrades[$date][$name][$row['CountryCode']] += $units;
				break;
			default:
				echo "Unrecognized ProductTypeIdentifier\n";
				continue 2;
		}
		$reportAppNames[$name] = 0;
	}
	$result->close();
	$reportAppNames = array_keys($reportAppNames);
	sort($appNames);
	$numApps = count($appNames);
}
$db->close();

?><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<head>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
<title>iTunes Connect Sales Reports</title>
<link rel="stylesheet" href="style.css" />
<script type="text/javascript">
// <![CDATA[
function bindRows() {
	var n = 0;
	while(row = document.getElementById("r" + n)) {
		row.onmouseover = function(){ this.className = 'rowOver'; };
		row.onmouseout = function(){ this.className = ''; };
		n++;
	}
}
// ]]>
</script>
</head>
<body onload="bindRows()">
<?php
// temporary output buffer
$echo = '';

////////////////////////////////////// IF WE SHOULD SHOW THE TABLE///////////
//if ($_POST['tbl_or_chrt'] == 'table') {
if( !isset($_POST['tbl_or_chrt']) or ($_POST['tbl_or_chrt'] == 'table'))
{
/////////////////////////////////////////////////////////////////////////////////


// Generate the header rows
$class = '';
foreach($dates as $d)
{
	$dateRow .= '<td colspan="' . $numApps . '">' . date('M d, Y',$d) . '</td>';
	$class = ($class == '') ? ' class="t3"' : '';
	foreach($reportAppNames as $name)
		$appRow .= '<td' . $class . '>' . $name . '</td>';
}
// Add a row-total column
$dateRow .= '<td colspan="' . $numApps . '">TOTAL</td>';
$class = ($class == '') ? ' class="t3"' : '';
foreach($reportAppNames as $app)
	$appRow .= '<td' . $class . '>' . $app . '</td>';

$echo .= '<p>&nbsp;</p><table class="t1">';
$echo .= '<tr class="h1"><td></td>'.$dateRow.'</tr>';
$echo .= '<tr class="h2"><td class="h1"></td>'.$appRow."</tr>\n";
// write unit count for each country for each day for each app
$rownum = 0;
foreach($langs as $cc => $cname) {
	// filter validcountries
	if (!empty($valid_countries) and !in_array($cc,$valid_countries)) continue;

	$row = '<tr id="r' . $rownum . '"><td class="h1" title="' . $cc . '">' . $cname . '</td>';
	$total_sales = 0;
	$total_upgrades = 0;
	$class = '';
	foreach( $dates as $d )
	{
		$date = date('Y-m-d',$d);
		foreach($reportAppNames as $name)
		{
			$numSales = $sales[$date][$name][$cc];
			$numUpgrades = $upgrades[$date][$name][$cc];
			$row .= '<td' . $class . '>';
			if( intval($numUpgrades) )
			{
				$row .= intval($numSales) ? $numSales : '0';
				$row .= ' / '.$numUpgrades;
			}
			else
				$row .= $numSales;
			$row .= '</td>';
			$total_sales += intval($numSales);
			$total_upgrades += intval($numUpgrades);
		}
		$class = ($class == '') ? ' class="t2"' : '';
	}
	if( $total_sales + $total_upgrades )
	{
		$echo .= $row;
		foreach( $reportAppNames as $name )
		{
			$echo .= '<td>';
			if( $total_upgrades )
			{
				$echo .= intval($total_sales) ? $total_sales : '0';
				$echo .= ' / '.$total_upgrades;
			}
			else
				$echo .= $numCountrySales[$name][$cc];
			$echo .= '</td>';
		}
		$echo .= "</tr>\n";
		$rownum++;
	}
}
// write totals for each day for each app
$echo .= '<tr class="h3"><td><b>TOTAL</b></td>';
$class = '';
foreach( $dates as $d )
{
	foreach($reportAppNames as $name)
	{
		$date = date('Y-m-d',$d);
		$numSales = $totalSales[$date][$name];
		$numUpgrades = $totalUpgrades[$date][$name];
		$echo .= '<td' . $class . '>';
		if( $numUpgrades )
		{
			$echo .= $numSales ? $numSales : '0';
			$echo .= ' / '.$numUpgrades;
		}
		else
			$echo .= $numSales;
		$echo .= '</td>';
	}
	$class = ($class == '') ? ' class="t2"' : '';
}
foreach($reportAppNames as $name)
{
	$echo .= '<td'.$class.'>'.$totalAppSales[$name].' / '.$totalAppUpgrades[$name].'</td>';
}
$echo .= '</tr></table>';

///////////////////////////////////////////////////////////
} else {   ///////// END IF FOR TABLE DISPLAY
////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////
////////////////// IF WE SHOULD SHOW THE CHART //////////////////////
if ($_POST['tbl_or_chrt']=='chart') {
	$qstr = '';
	// if specific dates were selected, append specific dates to query string
	if($datesSelected) {
		$qstr .= 'd=';
		foreach($dates as $d)
			$qstr .= $d . ',';
		$qstr = rtrim($qstr,',') . '&amp;';
	}
	// if specific apps were selected, append names to query string
	if($appsSelected) {
		$qstr .= 'a=';
		foreach($appNames as $a) {
			if(strlen(trim($a)) > 0)
				$qstr .= urlencode($a) . ',';
		}
		$qstr = rtrim($qstr,',');
	}
	$echo .= '<p><img src="chart.php?' . $qstr . '" alt="" /></p>';
}
////////////////////////////////
} ////// END ELSE /////////////
////////////////////////////////

// TOP FORM WITH DATE/APP/REGION CHECKBOXES
?><form action="" method="post">
	<div class="topform">
		<table>
			<thead>
				<tr>
					<td rowspan=2>&gt;&gt; <?= $numApps . ' Application'.(($numApps != 1) ? 's' : '') ?></td>
					<td colspan=2>Totals</td>
					<td colspan=2>Daily Averages</td>
				</tr>
				<tr>
					<td>Sales</td>
					<td>Updates</td>
					<td>Sales</td>
					<td>Updates</td>
				</tr>
			</thead>
			<tfoot>
				<tr>
					<td>Total</td>
					<td><?= $appTotalSales ?></td>
					<td><?= $appTotalUpdates ?></td>
					<td></td>
					<td></td>
				</tr>
			</tfoot>
			<tbody class="scroll">
<?php
foreach($appNames as $a)
{
	echo '<tr><td><input type="checkbox" name="chk_apps[]" value="' . $a . '"';
	if(empty($reportAppNames) or in_array($a,$reportAppNames)) echo ' checked="checked"';
	echo ' />' . $a;
	echo '</td><td>'.$appSales[$a].'</td><td>'.$appUpdates[$a].'</td><td>'.$avgDailySales[$a].'</td><td>'.$avgDailyUpdates[$a].'</td></tr>'."\n";
}
?>
			</tbody>
		</table>
	</div>
	<div class="topform">
		<table>
			<thead>
				<td>&gt;&gt; <?= $numDates . ' Daily Reports' ?></td>
				<td>Sales</td>
				<td>Upgrades</td>
			</thead>
			<tbody class="scroll">
<?php
foreach($allDates as $d)
{
	echo '<tr><td><input type="checkbox" name="chk_dates[]" value="' . date('Y-m-d',$d) . '"';
	if( in_array($d,$dates) )
		echo ' checked="checked"';
	echo ' /> ' . date('M d, Y', $d) . '</td>';
	echo '<td>'.$dateSales[$d].'</td><td>'.$dateUpgrades[$d].'</td></tr>';
}
?>
			</tbody>
		</table>
	</div>
	<div class="topform">
		<table>
			<thead>
				<td>&gt;&gt; <?= count($regions) . ' Regions' ?></td>
				<td>Sales</td>
				<td>Upgrades</td>
			</thead>
			<tbody>
<?php
foreach($regions as $reg => $arr)
{
	echo '<tr><td><input type="checkbox" name="chk_regions[]" value="' . $reg . '"';
	if(empty($valid_regions) or in_array($reg,$valid_regions)) echo ' checked="checked"';
	echo ' />' . $reg . '</td><td>'.$regionSales[$reg].'</td><td>'.$regionUpgrades[$reg].'</td></tr>';
}
?>
			</tbody>
		</table>
	</div>
	<div class="topform">
		<input type="submit" name="submit" value="Update" /><br />
		<input type="radio" name="tbl_or_chrt" value="table"
<?= ($_POST['tbl_or_chrt']=='' or $_POST['tbl_or_chrt']=='table') ? ' checked="checked"' : ''; ?> />Show Table<br />
		<input type="radio" name="tbl_or_chrt" value="chart" ';
<?= ($_POST['tbl_or_chrt']=='chart') ? ' checked="checked"' : ''; ?> /> Show Chart<br />
	</div>
</form>
<div style="clear:both;"></div>
<?= $echo ?>
	</body>
</html>



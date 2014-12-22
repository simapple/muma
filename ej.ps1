function isset($var){
	return -not [string]::IsNullOrEmpty($var)
}

function sethostname($hostname){
	if ($hostname){
		$computer=Get-WMIObject -class Win32_ComputerSystem
		$computer.Rename($hostname);
	}
}

function setrootpass($password){
	if ($password){
		net user Administrator $password
	}
}


function setmysqlpass($password){
	if ($password){
		if (Test-Path "D:\SOFT_PHP_PACKAGE\mysql\bin\mysqladmin.exe"){
		     for($i=0;$i -lt 180;$i++)
		     {        
			 D:\SOFT_PHP_PACKAGE\mysql\bin\mysqladmin.exe -uroot -proot3306 password $password
			 if($?)
			 { 
				break
			 }
			 else   
			  {
				net start mysql
				Start-Sleep -Seconds 1
			  }
		      }

			if (Test-Path "D:\SOFT_PHP_PACKAGE\iistool4.mdb"){
				$connection = New-Object -ComObject ADODB.Connection
				$connection.Open("Provider = Microsoft.Jet.OLEDB.4.0;Data Source=D:\SOFT_PHP_PACKAGE\iistool4.mdb" )
				$sql="update variable set varValue='" + $password + "' where varName='rootpass'"
				$connection.execute($sql)
				$connection.close()
			}
		}
	}
}

function getlocalmac(){
		$wmi=Get-WMIObject -class win32_networkAdapterConfiguration -filter "ipenabled=true" -computer .
		if ($wmi){
			return $wmi[0].MacAddress
		}
}

function setnetwork($ipaddr,$netmask,$gateway,$mac){
	if (isset($ipaddr) -and isset($netmask) -and isset($gateway)){
		$dns=@("1.2.4.8","114.114.114.114")
		for($i=0;$i -le 60;$i++){
			$filter="ipenabled=true and macaddress='" + $mac + "'"
			$wmi=Get-WMIObject -class win32_networkAdapterConfiguration -filter $filter -computer .
			$code=$wmi.EnableStatic($ipaddr,$netmask)
			$xx=$code.ReturnValue
			#add-content "c:/setiplog.txt" "(enabel-static:$xx,$ipaddr,$netmask)"
			if ($xx -eq 0){
				break;
			}else{
				start-sleep -s 2
			}
		}
		$code=$wmi.SetGateways($gateway)
		$xx=$code.ReturnValue
		#add-content "c:/setiplog.txt" "(gateway:$xx)"
		$code=$wmi.SetDNSServerSearchOrder($dns)
		$xx=$code.ReturnValue
		#add-content "c:/setiplog.txt" "(dns:$xx)"
	}
}

function setnetwork_pri($ipaddr,$netmask,$mac){
	if (isset($ipaddr) -and isset($netmask)){
		for($i=0;$i -le 60;$i++){
			$filter="ipenabled=true and macaddress<>'" + $mac + "'"
			$wmi=Get-WMIObject -class win32_networkAdapterConfiguration -filter $filter -computer .
			$code=$wmi.EnableStatic($ipaddr,$netmask)
			$xx=$code.ReturnValue
			#add-content "c:/setiplog.txt" "set inner ip $ipaddr,$netmask($xx)"
			if ($xx -eq 0){
				break;
			}else{
				start-sleep -s 2
			}
			
		}

	}
}

function diskextend($flg){
	if ($flg -eq "no"){
		"select disk 1","online disk","att disk clear readonly","select volume 0","extend","select volume 1","extend","select volume 2","extend","exit"|diskpart
	}
	if (!(test-path "d:\"))
	{
		"select volume 0","assign","select volume 1","assign","select volume 2","assign","exit"|diskpart
	}
}

$port=new-Object System.IO.Ports.SerialPort COM1
$port.Open();

$info=@{}
$port.WriteLine("ready");

while($true){
	$data=$port.ReadLine();

	$mesg="get cmd:" + $data+",len:"+$data.length
	#add-content "c:/setiplog.txt" $mesg
	
	$pos=$data.indexOf(":");
	
	if ($pos -gt 0 ){
		$key=$data.substring(0,$pos)
		$val=$data.substring($pos+1)
		$info[$key]=$val

		if ($key -eq "setpwd"){
			setrootpass($val)	
		}
	}
	
	if ($data.StartsWith("quit")){
		break
	}
}

if (!(isset($info.pubmac))){
	$info["pubmac"]=getlocalmac
}

#diskextend($info.reinstall)
diskextend("no")
setrootpass($info.password)
sethostname($info.hostname)
setnetwork $info.ipaddr $info.netmask $info.gateway $info.pubmac
setnetwork_pri $info.privateaddr $info.privatemask $info.pubmac
setmysqlpass($info.password)

$port.WriteLine("ok"); 
$port.Close();

#schtasks /Delete /F /TN "setip"
#Remove-Item C:\windows\setip.ps1

shutdown -r -t 0

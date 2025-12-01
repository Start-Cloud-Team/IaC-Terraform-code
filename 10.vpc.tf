resource "aws_vpc" "iac-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

#서브넷
resource "aws_subnet" "iac-public-subnet1"{
  vpc_id = aws_vpc.iac-vpc.id
  cidr_block = "10.0.5.0/24"
  availability_zone = "ap-northeast-2a"
}

resource "aws_subnet" "iac-public-subnet2"{
  vpc_id = aws_vpc.iac-vpc.id
  cidr_block = "10.0.6.0/24"
  availability_zone = "ap-northeast-2c"
}

resource "aws_subnet" "iac-private-subnet1"{
  vpc_id = aws_vpc.iac-vpc.id
  cidr_block = "10.0.7.0/24"
  availability_zone = "ap-northeast-2a"
}

resource "aws_subnet" "iac-private-subnet2"{
  vpc_id = aws_vpc.iac-vpc.id
  cidr_block = "10.0.8.0/24"
  availability_zone = "ap-northeast-2c"
}

#인터넷 게이트웨이
resource "aws_internet_gateway" "iac-igw"{
  vpc_id = aws_vpc.iac-vpc.id
}

#eip 설정
resource "aws_eip" "iac-eip-2a"{
  
}

resource "aws_eip" "iac-eip-2c"{
  
}

#nat 게이트웨이
resource "aws_nat_gateway" "iac_nat_gateway1" {
  allocation_id = aws_eip.iac-eip-2a.id
  subnet_id = aws_subnet.iac-public-subnet1.id 

  depends_on = [
    aws_internet_gateway.iac-igw
  ]
}

resource "aws_nat_gateway" "iac_nat_gateway2" {
  allocation_id = aws_eip.iac-eip-2c.id
  subnet_id = aws_subnet.iac-public-subnet2.id 

  depends_on = [
    aws_internet_gateway.iac-igw
  ]
}

#라우팅 테이블
resource "aws_route_table" "iac-private1-route-table"{
  vpc_id = aws_vpc.iac-vpc.id
}

resource "aws_route_table" "iac-private2-route-table"{
  vpc_id = aws_vpc.iac-vpc.id
}

resource "aws_route_table" "iac-public-route-table"{
  vpc_id = aws_vpc.iac-vpc.id
}

#라우팅 테이블 - 서브넷 연결
resource "aws_route_table_association" "iac-attach-route-table-subnet1" {
  subnet_id      = aws_subnet.iac-public-subnet1.id
  route_table_id = aws_route_table.iac-public-route-table.id
}

resource "aws_route_table_association" "iac-attach-route-table-subnet2" {
  subnet_id      = aws_subnet.iac-public-subnet2.id
  route_table_id = aws_route_table.iac-public-route-table.id
}

resource "aws_route_table_association" "iac-attach-route-table-subnet3" {
  subnet_id      = aws_subnet.iac-private-subnet1.id
  route_table_id = aws_route_table.iac-private1-route-table.id
}

resource "aws_route_table_association" "iac-attach-route-table-subnet4" {
  subnet_id      = aws_subnet.iac-private-subnet2.id
  route_table_id = aws_route_table.iac-private2-route-table.id
}

#라우트 규칙
resource "aws_route" "iac-route-rule1" {
  route_table_id         = aws_route_table.iac-private1-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.iac_nat_gateway1.id
}

resource "aws_route" "iac-route-rule2" {
  route_table_id         = aws_route_table.iac-private2-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.iac_nat_gateway2.id
}

resource "aws_route" "iac-route-rule3" {
  route_table_id         = aws_route_table.iac-public-route-table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.iac-igw.id
}

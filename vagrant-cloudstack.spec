%define gemdir /usr/lib/vagrant-cloudstack/gems
Name:	 vagrant-cloudstack
Version:	%{gemver}
Release:	3%{?dist}
Summary:	vagrant cloudstack plugin

License:	MIT
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Source0:        vagrant-cloudstack-%{version}.tar.gz
BuildRequires:  rubygems 
Requires:	vagrant >= 1.2.0 libxml2-devel libxslt-devel libffi-devel ruby-devel

%description
vagrant cloudstack


%prep
%setup -q

%build
bundle package
gem build vagrant-cloudstack.gemspec


%install
mkdir -p %{buildroot}/%{gemdir}
cp vagrant-cloudstack-%{version}.gem %{buildroot}/%{gemdir}
cp vendor/cache/*.gem %{buildroot}/%{gemdir}


%clean
rm -rf %{buildroot}


%post
cd %{gemdir}
gem install --local fog --no-rdoc --no-ri

%files
%defattr(-,root,root,-)
%{gemdir}

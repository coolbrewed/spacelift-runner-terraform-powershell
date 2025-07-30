# Start PowerShell installer stage
FROM public.ecr.aws/spacelift/runner-terraform:latest AS pwsh-installer

# Arguments for PowerShell 7 version and installation
ARG PS_VERSION=7.5.1
ARG PS_PACKAGE_URL=https://github.com/PowerShell/PowerShell/releases/download/v${PS_VERSION}/powershell-${PS_VERSION}-linux-musl-x64.tar.gz

# Temporarily elevate permissions
USER root

# Download PowerShell
ADD ${PS_PACKAGE_URL} /tmp/powershell.tar.gz

# Unzip to the installation directory
RUN mkdir -p /opt/microsoft/powershell/7 && \
    tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 -v

# Start final stage
FROM public.ecr.aws/spacelift/runner-terraform:latest AS final

# Temporarily elevate permissions
USER root

# Copy PowerShell from the installer stage
COPY --from=pwsh-installer ["/opt/microsoft/powershell", "/opt/microsoft/powershell"]

# Set environment variables for PowerShell
ENV POWERSHELL_TELEMETRY_OPTOUT=1 \
    DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    PSModuleAnalysisCachePath=/var/cache/microsoft/powershell/PSModuleAnalysisCache/ModuleAnalysisCache

# Install and update packages
RUN apk add --no-cache \
    ca-certificates \
    less \
    ncurses-terminfo-base \
    krb5-libs \
    libgcc \
    libintl \
    libssl3 \
    libstdc++ \
    tzdata \
    userspace-rcu \
    zlib \
    icu-libs \
    curl && \
    apk -X https://dl-cdn.alpinelinux.org/alpine/edge/main add --no-cache lttng-ust openssh-client && \
    apk update && \
    apk upgrade

# Configure PowerShell, install and configure PowerCLI
# Important: `Set-PowerCLIConfiguration -ParticipateInCEIP $false` disables disruptive message injection that will break Terraform external data source calls
RUN chmod a+x /opt/microsoft/powershell/7/pwsh && \
    ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
    pwsh -NoLogo -NoProfile -Command " \
    \$ErrorActionPreference = 'Stop' ; \
    \$ProgressPreference = 'SilentlyContinue' ; \
    Install-Module -Name VCF.PowerCLI -Scope AllUsers -Force ; \
    Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP \$false -Confirm:\$false" && \
    pwsh --version

# Back to the restricted "spacelift" user
USER spacelift
# Kekeli-HomeCloud System Architecture

## Architecture Overview

### Design Philosophy
The Kekeli-HomeCloud architecture is built on the principle of **"Complexity Hidden, Simplicity Exposed"**. We extract the sophisticated automation from the proven `home-nextcloud` project and wrap it in user-friendly interfaces that require minimal technical knowledge.

### Core Architecture Principles
1. **Modular Design**: Independent components that can be tested and maintained separately
2. **Progressive Enhancement**: Basic functionality first, advanced features layered on top
3. **Fail-Safe Defaults**: Secure, working defaults that can be customized later
4. **Error Recovery**: Graceful handling of failures with clear recovery paths
5. **Platform Awareness**: Adaptive behavior based on detected environment

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Kekeli-HomeCloud Installer               │
├─────────────────────────────────────────────────────────────┤
│  install.sh (Main Entry Point)                             │
│  ├── User Interface Layer                                   │
│  ├── Configuration Wizard                                   │
│  └── Progress Monitoring                                    │
├─────────────────────────────────────────────────────────────┤
│  Core Installation Engine                                   │
│  ├── scripts/check-requirements.sh                         │
│  ├── scripts/setup-docker.sh                               │
│  ├── scripts/setup-storage.sh                              │
│  ├── scripts/setup-networking.sh                           │
│  ├── scripts/setup-nextcloud.sh                            │
│  └── scripts/verify-installation.sh                        │
├─────────────────────────────────────────────────────────────┤
│  Configuration Management                                   │
│  ├── templates/docker-compose.yml.template                 │
│  ├── templates/.env.template                               │
│  └── templates/settings.conf                               │
├─────────────────────────────────────────────────────────────┤
│  Utility Layer                                             │
│  ├── utils/logging.sh                                      │
│  ├── utils/network-detection.sh                            │
│  ├── utils/storage-detection.sh                            │
│  └── utils/error-handling.sh                               │
└─────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────┐
│                    Target System Environment                │
├─────────────────────────────────────────────────────────────┤
│  Docker Infrastructure                                      │
│  ├── nextcloud-app container                               │
│  ├── nextcloud-db (PostgreSQL) container                   │
│  └── redis container                                       │
├─────────────────────────────────────────────────────────────┤
│  Storage Layer                                             │
│  ├── Local Storage (Docker volumes)                        │
│  └── External Storage (UUID-mounted drives)                │
├─────────────────────────────────────────────────────────────┤
│  Network Layer                                             │
│  ├── Local Network Access                                  │
│  ├── Mobile Device Access                                  │
│  └── Firewall Configuration                                │
└─────────────────────────────────────────────────────────────┘
```

## Component Architecture

### 1. User Interface Layer

#### Main Installer (`install.sh`)
**Purpose**: Primary entry point that orchestrates the entire installation process
**Responsibilities**:
- Welcome user and explain installation process
- Gather user preferences through interactive prompts
- Coordinate execution of installation phases
- Provide real-time progress feedback
- Handle high-level error scenarios

**Key Features**:
- Interactive configuration wizard
- Progress bars and status indicators
- Colored output for better readability
- Graceful error handling with recovery suggestions
- Summary of final configuration

#### Configuration Wizard
**Purpose**: Guide users through configuration choices with smart defaults
**Responsibilities**:
- Present configuration options in user-friendly language
- Validate user inputs and suggest corrections
- Provide context and explanations for technical concepts
- Generate configuration files from user choices

**User Interaction Flow**:
```
Welcome → System Check → Storage Selection → Network Configuration →
Account Setup → Confirmation → Installation → Success/Failure
```

### 2. Core Installation Engine

#### Requirements Checker (`scripts/check-requirements.sh`)
**Purpose**: Validate system compatibility before installation begins
**Extracted From**: Manual verification steps in `home-nextcloud` setup

**Validation Checks**:
- Operating system and version compatibility
- Available disk space (minimum 4GB, recommended 10GB+)
- RAM availability (minimum 2GB, recommended 4GB+)
- Network connectivity and port availability
- User permissions (sudo access)
- Package manager functionality
- Existing Docker installation status

**Output**: Pass/fail status with specific remediation steps for failures

#### Docker Setup (`scripts/setup-docker.sh`)
**Purpose**: Install and configure Docker environment
**Extracted From**: Docker setup portions of `start-nextcloud.sh`

**Installation Process**:
1. Detect existing Docker installation
2. Install Docker CE and Docker Compose if missing
3. Configure Docker daemon settings
4. Add user to docker group
5. Start and enable Docker service
6. Validate Docker functionality with test container

**Error Handling**: Package installation failures, permission issues, service startup problems

#### Storage Configuration (`scripts/setup-storage.sh`)
**Purpose**: Detect and configure storage for Nextcloud data
**Extracted From**: `setup-complete-solution.sh` and storage mounting logic

**Storage Detection Process**:
1. Scan for external storage devices
2. Identify optimal mount points
3. Check existing mount configurations
4. Create UUID-based mount entries in `/etc/fstab`
5. Configure permissions for Docker access
6. Validate storage accessibility

**Supported Storage Types**:
- USB external drives
- SATA drives
- NVMe drives
- Network storage (future enhancement)

#### Network Configuration (`scripts/setup-networking.sh`)
**Purpose**: Configure network access for local and mobile connectivity
**Extracted From**: IP detection and networking logic in `auto-setup-mobile.sh`

**Network Setup Process**:
1. Detect local network configuration
2. Identify optimal IP addresses for access
3. Configure firewall rules for secure access
4. Set up trusted domains for Nextcloud
5. Configure port forwarding (WSL2 scenarios)
6. Generate mobile connection information

**Platform-Specific Handling**:
- Native Linux: iptables/ufw configuration
- WSL2: Windows firewall and port forwarding
- Complex networks: Multiple interface detection

#### Nextcloud Deployment (`scripts/setup-nextcloud.sh`)
**Purpose**: Deploy and configure Nextcloud containers
**Extracted From**: Container deployment logic in `start-nextcloud.sh`

**Deployment Process**:
1. Generate docker-compose.yml from template
2. Configure environment variables
3. Deploy PostgreSQL database container
4. Deploy Redis cache container
5. Deploy Nextcloud application container
6. Configure initial admin account
7. Set up external storage mounts
8. Configure trusted domains and security settings

#### Installation Verification (`scripts/verify-installation.sh`)
**Purpose**: Comprehensive testing of installation success
**Extracted From**: Testing logic in `troubleshoot-mobile.sh`

**Verification Tests**:
- Container health and status
- Web interface accessibility
- Database connectivity
- Storage mount verification
- Mobile connectivity testing
- Performance baseline checks

### 3. Configuration Management System

#### Template Engine
**Purpose**: Generate configuration files from user inputs and system detection

**Template Processing**:
- Variable substitution in configuration templates
- Conditional configuration based on detected environment
- Validation of generated configurations
- Backup of original configurations

**Key Templates**:
- `docker-compose.yml.template`: Container orchestration
- `.env.template`: Environment variables
- `settings.conf`: User preferences and system settings

#### Configuration Validation
**Purpose**: Ensure generated configurations are valid and secure

**Validation Checks**:
- Syntax validation for all configuration files
- Security validation (strong passwords, secure defaults)
- Compatibility validation (Docker version compatibility)
- Resource validation (adequate resources for configuration)

### 4. Utility Layer

#### Logging System (`utils/logging.sh`)
**Purpose**: Comprehensive logging for troubleshooting and progress tracking

**Logging Features**:
- Multiple log levels (DEBUG, INFO, WARN, ERROR)
- Colored terminal output
- File-based logging for troubleshooting
- User-friendly progress messages
- Technical details for advanced users

#### Network Detection (`utils/network-detection.sh`)
**Purpose**: Intelligent network environment detection
**Extracted From**: Advanced IP detection in `start-nextcloud.sh`

**Detection Capabilities**:
- Multiple network interface handling
- WSL2 vs native Linux detection
- Dynamic IP address resolution
- Firewall status detection
- Port availability checking

#### Storage Detection (`utils/storage-detection.sh`)
**Purpose**: Comprehensive storage device detection and analysis
**Extracted From**: Storage detection logic in various setup scripts

**Detection Features**:
- Block device enumeration
- File system type detection
- Mount point analysis
- Available space calculation
- Permission assessment

#### Error Handling (`utils/error-handling.sh`)
**Purpose**: Standardized error handling and user guidance

**Error Handling Features**:
- Standardized error codes
- User-friendly error messages
- Automated recovery suggestions
- Cleanup procedures for failed operations
- Support information and resources

## Data Flow Architecture

### Installation Data Flow
```
User Input → Validation → System Detection → Configuration Generation →
Component Installation → Verification → Success Report
```

### Runtime Data Flow
```
User Request → Web Interface → Nextcloud App → Database/Storage →
Response Processing → User Interface Update
```

### Mobile Access Data Flow
```
Mobile App → Network Discovery → Authentication → File Operations →
Local Storage → Database Updates → Sync Confirmation
```

## Security Architecture

### Security Layers
1. **Network Security**: Firewall configuration, trusted domains
2. **Container Security**: Minimal attack surface, secure defaults
3. **Storage Security**: Proper file permissions, encryption ready
4. **Access Control**: Strong authentication, role-based permissions
5. **Communication Security**: SSL/TLS ready, secure protocols

### Security Implementation
- **Default Deny**: All unnecessary services disabled
- **Principle of Least Privilege**: Minimal required permissions
- **Defense in Depth**: Multiple security layers
- **Secure Defaults**: Security-first configuration choices

## Performance Architecture

### Performance Optimization Strategies
1. **Resource Efficiency**: Optimized container configurations
2. **Caching Strategy**: Redis for session and object caching
3. **Storage Optimization**: Efficient file system choices
4. **Network Optimization**: Local network prioritization
5. **Database Tuning**: PostgreSQL optimization for file workloads

### Scalability Considerations
- **Container Scaling**: Ready for multi-container deployments
- **Storage Scaling**: External storage expansion support
- **User Scaling**: Multi-user configuration options
- **Network Scaling**: Multiple network interface support

## Platform-Specific Adaptations

### Linux Native
- Direct hardware access
- Native networking stack
- System service integration
- Package manager utilization

### WSL2 Environment
- Windows host integration
- Cross-platform networking
- Windows firewall configuration
- Hybrid storage access

### Future Windows Branch
- Docker Desktop integration
- Windows service management
- Native Windows networking
- Windows-specific storage handling

## Testing Architecture

### Testing Strategy
1. **Unit Testing**: Individual component validation
2. **Integration Testing**: Component interaction validation
3. **System Testing**: End-to-end installation validation
4. **User Testing**: Real user scenario validation
5. **Performance Testing**: Resource usage and speed validation

### Test Environment Matrix
- **Operating Systems**: Ubuntu 20.04/22.04, Debian 11/12, WSL2
- **Hardware Configs**: Minimum spec, recommended spec, high-end
- **Network Scenarios**: Simple, complex, constrained
- **Storage Scenarios**: Internal only, external USB, multiple drives

## Monitoring and Observability

### System Monitoring
- Container health monitoring
- Resource usage tracking
- Storage space monitoring
- Network connectivity status

### User Experience Monitoring
- Installation success rates
- Common failure points
- Performance metrics
- User feedback integration

## Future Architecture Enhancements

### Phase 2 Enhancements
- Windows platform support
- Enhanced mobile integration
- Advanced security features
- Performance optimizations

### Phase 3 Enhancements
- Cloud backup integration
- Multi-node deployments
- Advanced monitoring
- Enterprise features

### Long-term Vision
- Plugin architecture
- API extensions
- Third-party integrations
- Cloud-hybrid deployments

This architecture provides a solid foundation for transforming the sophisticated `home-nextcloud` project into a user-friendly installer while maintaining all the robustness and functionality of the original system.